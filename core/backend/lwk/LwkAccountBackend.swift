import Foundation
import LiquidWalletKit
import greenaddress
import hw

public class LwkAccountBackend: AccountBackend {

    private static let GAP_LIMIT = 20

    let wollet: Wollet
    let signer: Signer
    let amp2: Amp2?
    @ThreadSafe public private(set) var account: Account
    @ThreadSafe public private(set) var assets: Assets = [:]
    @ThreadSafe public private(set) var txs = [String: Transaction]()
    @ThreadSafe private var nextAddressIndex: Int = 0
    public var hasTxs: Bool { !txs.isEmpty }
    public weak var networkBackend: LwkNetworkBackend?


    init(
        networkBackend: LwkNetworkBackend,
        wollet: Wollet,
        signer: Signer,
        account: Account,
        amp2: Amp2?
    ) {
        self.networkBackend = networkBackend
        self.wollet = wollet
        self.signer = signer
        self.account = account
        self.amp2 = amp2
        self.assets = Assets()
    }

    public func getReceiveAddress() async throws -> Address {
        let firstUnusedIndex = Int(try wollet.address(index: nil).index())
        // Hand out addresses past the wallet's first-unused index, but stay
        // within the BIP44 gap limit so we don't generate addresses the wallet won't scan.
        var reservedIndex = 0
        _nextAddressIndex.mutate { nextIndex in
            if nextIndex < firstUnusedIndex || nextIndex - firstUnusedIndex >= Self.GAP_LIMIT {
                nextIndex = firstUnusedIndex
            }
            reservedIndex = nextIndex
            nextIndex += 1
        }
        let address = try wollet.address(index: UInt32(reservedIndex))
        print("Address #\(address.index()) \(address.address())")
        return Address(address: address.address().description)
    }

    public func getBalance(confirmations: Int) async throws -> [String: Int64] {
        let balances = try wollet.balance().mapValues { Int64($0) }
        print("Balance \(balances)")
        assets = balances
        return balances
    }

    public func getTransactions(params: GetTransactionsParams) async throws -> Transactions {
        let transactions: [Transaction] = try wollet.transactionsPaginated(
            offset: UInt32(params.first),
            limit: UInt32(params.count)
        ).map { walletTx in
            var tx = Transaction([:], accountId: account.id)
            tx.blockHeight = walletTx.height() ?? 0
            // Use a max timestamp sentinel so undated LWK txs sort first.
            tx.createdAtTs = Int64(walletTx.timestamp() ?? UInt32.max) * 1_000_000
            tx.inputs = walletTx
                .inputs()
                .compactMap { $0?.toInputOutput(isOutput: false) }
            tx.outputs = walletTx
                .outputs()
                .compactMap { $0?.toInputOutput(isOutput: true) }
            tx.fee = walletTx.fee()
            tx.feeRate = 0
            tx.hash = walletTx.txid().description
            tx.amounts = walletTx.balance()
            tx.type = TransactionType(rawValue: walletTx.type()) ?? .unknown
            if let explorerUrl = networkBackend?.network.explorerUrl {
                tx.unblindingUrl = walletTx.unblindedUrl(explorerUrl: explorerUrl)
            }
            return tx
        }
        _txs.mutate { cache in
            for tx in transactions {
                if let txHash = tx.hash {
                    cache[txHash] = tx
                }
            }
        }
        return Transactions(list: transactions)
    }

    public func createTransaction(params: Transaction) async throws -> Transaction {
        guard params.addressees.count == 1 else {
            throw GaError.GenericError("Only 1 addressee is supported")
        }
        guard let recipient = params.addressees.first else {
            throw GaError.GenericError("No recipient address provided")
        }
        guard let recipientAsset = recipient.assetId else {
            throw GaError.GenericError("Recipient without assetId")
        }
        guard let networkBackend else {
            throw GaError.GenericError("Backend not initialized")
        }
        let recipientAddress = try LiquidWalletKit.Address(s: recipient.address)
        let builder = networkBackend.lwkNetwork.txBuilder()
        if recipient.isGreedy ?? false {
            if networkBackend.isPolicyAsset(assetId: recipientAsset) {
                try builder.drainLbtcWallet()
                try builder.drainLbtcTo(address: recipientAddress)
            } else {
                guard let satoshi = try wollet.balance()[recipientAsset], satoshi > 0 else {
                    throw GaError.GenericError("No balance available for send all")
                }
                try builder.addRecipient(
                    address: recipientAddress,
                    satoshi: satoshi,
                    asset: recipientAsset
                )
            }
        } else if let satoshi = recipient.satoshi {
            try builder.addRecipient(
                address: recipientAddress,
                satoshi: UInt64(satoshi),
                asset: recipientAsset
            )
        } else {
            throw GaError.GenericError("No satoshi provided")
        }
        let pset = try builder.finish(wollet: wollet)
        let balance = try wollet.psetDetails(pset: pset).balance()
        let transaction = try pset.extractTx()
        var tx = params
        tx.fee = balance.fee()
        let recipients: [TxInputOutput] = balance.recipients().map {
            return TxInputOutput(
                address: $0.address()?.description,
                isChange: false,
                satoshi: $0.value() != nil ? Int64($0.value()!) : 0,
                assetId: $0.asset()
            )
        }
        if recipient.isGreedy ?? false {
            let destination: TxInputOutput?
            if let externalRecipient = recipients.first {
                destination = externalRecipient
                tx.outputs = recipients
            } else {
                // A wallet-owned destination is not included in PsetBalance.recipients.
                // Resolve it from the PSET using the requested asset and address script.
                let outputs: [TxInputOutput] = pset.outputs().map {
                    return TxInputOutput(
                        satoshi: $0.amount()?.int64(),
                        assetId: $0.asset(),
                        script: $0.scriptPubkey().description
                    )
                }
                destination = outputs.first {
                    $0.assetId == recipientAsset &&
                    $0.script == recipientAddress.scriptPubkey().description
                }
                tx.outputs = outputs
            }
            guard let recipientSatoshi = destination?.satoshi,
                  recipientSatoshi > 0 else {
                throw GaError.GenericError("Unable to resolve send all recipient amount")
            }
            tx.addressees[0].satoshi = recipientSatoshi
            tx.amounts = [recipientAsset: -recipientSatoshi]
        } else {
            tx.outputs = recipients
            var balances = balance.balances()
            if let feeAsset = networkBackend.gdkNetwork.policyAsset {
                balances[feeAsset] = (balances[feeAsset] ?? 0) + Int64(balance.fee())
            }
            tx.amounts = balances
        }

        tx.transaction = transaction.bytes().hex
        tx.hash = transaction.txid().description
        tx.pset = pset.description
        return tx
    }

    public func getOutputDescriptors() async throws -> String? {
        return try wollet.descriptor().description
    }

    public func getUnspentOutputs(isBump: Bool, isExpired: Bool, expiredAt: UInt64?) async throws -> [String: [UnspentOutput]] {
        throw GaError.GenericError("Not implemented")
    }
    public func signTransaction(createTransaction: Transaction) async throws -> Transaction {
        guard let psetStr = createTransaction.pset else {
            throw GaError.GenericError("Required primitive PSET data field is null" )
        }
        let pset = try Pset(base64: psetStr)
        var signedPset = try signer.sign(pset: pset)
        if let amp2 {
            signedPset = try amp2.cosign(pset: signedPset)
        }
        let signedTransaction = try signedPset.finalize()
        var updatedTx = createTransaction
        updatedTx.transaction = signedTransaction.bytes().toHex()
        return updatedTx
    }
}
