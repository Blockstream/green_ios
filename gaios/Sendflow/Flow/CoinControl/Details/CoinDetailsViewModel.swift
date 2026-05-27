import Foundation
import UIKit
import core

enum CoinDetailRowType {
    case amount(satoshi: String?, fiat: String?)
    case status(_ isUnconfirmed: Bool)
    case received(timestamp: Int64)
    case receivedOn(address: String)
    case transactionId(txid: String)
    case outputIndex(index: UInt32)
    case scriptType(type: String)
    case blockHeight(height: UInt64?)
    case note(text: String)

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d. MMM HH:mm"
        return formatter
    }()

    var title: String {
        switch self {
        case .amount: return "Amount".localized
        case .status: return "Status".localized
        case .received: return "Received".localized
        case .receivedOn: return "Received on".localized
        case .transactionId: return "Transaction ID".localized
        case .outputIndex: return "Output Index".localized
        case .scriptType: return "Script Type".localized
        case .blockHeight: return "Block Height".localized
        case .note: return "Note".localized
        }
    }

    var view: UIView {
        switch self {
        case let .amount(satoshi, fiat):
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .trailing
            stack.spacing = 0
            if let satoshi = satoshi {
                stack.addArrangedSubview(makeLabel(text: satoshi))
            }
            if let fiat = fiat {
                stack.addArrangedSubview(makeLabel(text: fiat))
            }
            return stack
        case let .status(isUnconfirmed):
            let text = isUnconfirmed ? "Unconfirmed".localized : "Confirmed".localized
            return makeLabel(text: text)
        case let .received(timestamp):
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1_000_000.0)
            return makeLabel(text: CoinDetailRowType.dateFormatter.string(from: date))
        case let .receivedOn(address):
            let textView = UITextView()
            textView.isScrollEnabled = false
            textView.isEditable = false
            textView.isSelectable = true
            textView.backgroundColor = .clear
            textView.textContainerInset = .zero
            textView.textContainer.lineFragmentPadding = 0
            AddressDisplay.configure(address: address, textView: textView, style: .coinDetails)
            return textView
        case let .transactionId(txid):
            return makeLabel(text: "\(txid.prefix(6))...\(txid.suffix(6))")
        case let .outputIndex(index):
            return makeLabel(text: "\(index)")
        case let .scriptType(type):
            return makeLabel(text: type)
        case let .blockHeight(height):
            let text = height != nil && height! > 0 ? "\(height!)" : "0"
            return makeLabel(text: text)
        case let .note(text):
            let label = makeLabel(text: text)
            label.numberOfLines = 0
            return label
        }
    }

    private func makeLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.setStyle(.txtSmaller)
        label.textColor = .gGrayTxt()
        label.textAlignment = .right
        return label
    }
}

class CoinDetailsViewModel {
    let utxo: UnspentOutput
    let network: GdkNetwork?
    let denomination: DenominationType?
    let isFiat: Bool
    
    private(set) var rows: [CoinDetailRowType] = []
    
    var urlForExplorer: URL? {
        return utxo.urlForTx(explorerUrl: network?.txExplorerUrl)
    }
    
    var explorerPreferenceKey: String? {
        guard let chain = network?.chain else { return nil }
        return chain + "_view_in_explorer"
    }
    
    var onUpdate: (() -> Void)?
    
    init(utxo: UnspentOutput, account: Account?, denomination: DenominationType? = nil, isFiat: Bool = false) {
        self.utxo = utxo
        self.denomination = denomination
        self.isFiat = isFiat

        let backend = account.flatMap { WalletManager.current?.accountBackendOrNil($0) }
        self.network = backend?.account.gdkNetwork
        
        let tx = backend?.txs[utxo.txhash ?? ""]
        let timestamp = tx?.createdAtTs
        let address = Self.extractAddress(tx: tx, utxo: utxo)
        let memo = tx?.memo

        buildRows(timestamp: timestamp, address: address, memo: memo)

        if timestamp == nil || address == nil, let account = account, let txhash = utxo.txhash {
            Task.detached { [weak self] in
                do {
                    if let fetchedTx = try await WalletManager.current?.getTransaction(id: txhash, subaccount: account) {
                        let newTimestamp = fetchedTx.createdAtTs
                        let newAddress = Self.extractAddress(tx: fetchedTx, utxo: utxo)
                        let newMemo = fetchedTx.memo

                        await MainActor.run {
                            self?.buildRows(timestamp: newTimestamp, address: newAddress, memo: newMemo)
                            self?.onUpdate?()
                        }
                    }
                } catch {
                    logger.error("CoinDetailsViewModel getTransaction error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private static func extractAddress(tx: core.Transaction?, utxo: UnspentOutput) -> String? {
        guard let tx = tx else { return nil }
        let outputIndex = Int(utxo.ptIdx ?? 0)
        let outputs = tx.outputs ?? []
        return outputs.first(where: { $0.ptIdx == Int64(outputIndex) })?.address ?? 
               (outputIndex < outputs.count ? outputs[outputIndex].address : nil)
    }
    
    private func buildRows(timestamp: Int64?, address: String?, memo: String?) {
        var newRows: [CoinDetailRowType] = []

        if let satoshi = utxo.satoshi {
            let assetId = utxo.assetId ?? AssetInfo.btcId
            let btcText = Balance.fromSatoshi(satoshi, assetId: assetId)?.toText(denomination)
            let fiatText = Balance.fromSatoshi(satoshi, assetId: assetId)?.toFiatText()
            
            newRows.append(.amount(
                satoshi: isFiat ? fiatText : btcText,
                fiat: fiatText)
            )
        }

        newRows.append(.status(utxo.isUnconfirmed))
        
        if let timestamp = timestamp, timestamp > 0 {
            newRows.append(.received(timestamp: timestamp))
        }

        if let address = address, !address.isEmpty {
            newRows.append(.receivedOn(address: address))
        }

        if let txhash = utxo.txhash {
            newRows.append(.transactionId(txid: txhash))
        }

        if let ptIdx = utxo.ptIdx {
            newRows.append(.outputIndex(index: ptIdx))
        }

        if let addressType = utxo.addressType {
            newRows.append(.scriptType(type: addressType.uppercased()))
        }

        newRows.append(.blockHeight(height: utxo.blockHeight))

        if let memo = memo, !memo.isEmpty {
            newRows.append(.note(text: memo))
        }

        self.rows = newRows
    }
}
