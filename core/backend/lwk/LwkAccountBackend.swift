import Foundation
import LiquidWalletKit
import greenaddress
import hw

public class LwkAccountBackend: AccountBackend {

    private static let GAP_LIMIT = 20

    let wollet: Wollet
    let signer: Signer
    let amp2: Amp2?
    public let account: Account
    public private(set) var assets: Assets = [:]
    public private(set) var txs = [String: Transaction]()
    public var hasTxs: Bool { !txs.isEmpty }
    public weak var networkBackend: LwkNetworkBackend?

    private var nextAddressIndex: Int = 0

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
        if nextAddressIndex < firstUnusedIndex || nextAddressIndex - firstUnusedIndex >= Self.GAP_LIMIT {
            nextAddressIndex = firstUnusedIndex
        }
        let address = try wollet.address(index: UInt32(nextAddressIndex))
        nextAddressIndex += 1
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
        if params.first > 0 {
            return Transactions(list: [])
        }
        let txs: [Transaction] = try wollet.transactions().map { walletTx in
            var tx = Transaction([:], accountId: account.id)
            tx.blockHeight = walletTx.height() ?? 0
            // Use a max timestamp sentinel so undated LWK txs sort first.
            tx.createdAtTs = Int64(walletTx.timestamp() ?? UInt32.max) * 1_000_000
            tx.inputs = []
            tx.outputs = []
            tx.fee = walletTx.fee()
            tx.hash = walletTx.txid().description
            tx.amounts = walletTx.balance()
            if let explorerUrl = networkBackend?.network.explorerUrl {
                tx.unblindingUrl = walletTx.unblindedUrl(explorerUrl: explorerUrl)
            }
            // fix for redeposit tx
            let testnet = networkBackend?.networkId.testnet ?? false
            let defaultNetworkId: NetworkId = testnet ? .lwkTestnet : .lwkMainnet
            let feeAsset = (
                networkBackend?.networkId ?? defaultNetworkId
            ).gdkNetwork.getFeeAsset()
            if let lbtc = tx.amounts[feeAsset], abs(lbtc) == walletTx.fee() && walletTx.type() == "outgoing" {
                tx.type = .redeposit
            } else {
                tx.type = TransactionType(rawValue: walletTx.type()) ?? .unknown
            }
            return tx
        }
        for tx in txs {
            if let txHash = tx.hash {
                self.txs[txHash] = tx
            }
        }
        return Transactions(list: txs)
    }

    public func createTransaction(params: Transaction) async throws -> Transaction {
        precondition(params.addressees.count == 1, "Only 1 addressee is supported")
        guard let recipient = params.addressees.first else {
            throw GaError.GenericError("No recipient address provided")
        }
        guard let recipientAsset = recipient.assetId else {
            throw GaError.GenericError("Recipient without assetId")
        }
        guard let networkBackend else {
            throw GaError.GenericError("Backend not initialized")
        }
        let builder = networkBackend.lwkNetwork.txBuilder()
        if recipient.isGreedy ?? false {
            let address = try LiquidWalletKit.Address(s: recipient.address)
            if networkBackend.isPolicyAsset(assetId: recipientAsset) {
                try builder.drainLbtcWallet()
                try builder.drainLbtcTo(address: address)
            } else {
                guard let satoshi = try wollet.balance()[recipientAsset], satoshi > 0 else {
                    throw GaError.GenericError("No balance available for send all")
                }
                try builder.addRecipient(
                    address: address,
                    satoshi: satoshi,
                    asset: recipientAsset
                )
            }
        } else if let satoshi = recipient.satoshi {
            try builder.addRecipient(
                address: LiquidWalletKit.Address(s: recipient.address),
                satoshi: UInt64(satoshi),
                asset: recipientAsset
            )
        } else {
            throw GaError.GenericError("No satoshi provided")
        }
        let pset = try builder.finish(wollet: wollet)
        let balance = try wollet.psetDetails(pset: pset).balance()
        let transaction = try pset.extractTx()
        let outputs: [TransactionInputOutput] = balance.recipients().map {
            return TransactionInputOutput(
                address: $0.address()?.description,
                assetId: $0.asset(),
                isChange: false,
                satoshi: $0.value() != nil ? Int64($0.value()!) : 0
            )
        }
        var customSatoshiMap = balance.balances()
        if let feeAsset = networkBackend.gdkNetwork.policyAsset {
            let prev = customSatoshiMap[feeAsset] ?? 0
            customSatoshiMap[feeAsset] = prev + Int64(balance.fee())
        }
        var tx = params
        tx.amounts = customSatoshiMap
        tx.fee = balance.fee()
        tx.outputs = outputs
        if recipient.isGreedy ?? false {
            guard outputs.count == 1, let recipientSatoshi = outputs.first?.satoshi, recipientSatoshi > 0 else {
                throw GaError.GenericError("Invalid send all recipient amount")
            }
            tx.addressees[0].satoshi = recipientSatoshi
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
