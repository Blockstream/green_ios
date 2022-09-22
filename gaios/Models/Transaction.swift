import Foundation

enum TransactionError: Error {
    case invalid(localizedDescription: String)
}

struct Addressee: Codable {

    enum CodingKeys: String, CodingKey {
        case address
        case satoshi
        case assetId = "asset_id"
    }

    let address: String
    let satoshi: Int64
    let assetId: String?

    init(address: String, satoshi: Int64, assetId: String? = nil) {
        self.address = address
        self.satoshi = satoshi
        self.assetId = assetId
    }
}

enum TransactionType: String {
    case incoming
    case outgoing
    case redeposit
    case mixed
}

struct Transaction {
    var details: [String: Any]
    var subaccount: Int?

    private func get<T>(_ key: String) -> T? {
        return details[key] as? T
    }

    init(_ details: [String: Any], subaccount: Int? = nil) {
        self.details = details
        self.subaccount = subaccount
    }

    var addressees: [Addressee] {
        get {
            let out: [[String: Any]] = get("addressees") ?? []
            return out.map { value in
                let address = value["address"] as? String
                let satoshi = value["satoshi"] as? Int64
                let assetId = value["asset_id"] as? String
                return Addressee(address: address!, satoshi: satoshi ?? 0, assetId: assetId)
            }
        }
        set {
            let addressees = newValue.map { addr -> [String: Any] in
                var out = [String: Any]()
                out["address"] = addr.address
                out["satoshi"] = addr.satoshi
                out["asset_id"] = addr.assetId
                return out
            }
            details["addressees"] = addressees
        }
    }

    var addresseesList: [String] {
        get { get("addressees") ?? [] }
    }

    var addresseesReadOnly: Bool {
        get { return get("addressees_read_only") ?? false }
    }

    var blockHeight: UInt32 {
        get { return get("block_height") ?? 0 }
    }

    var canRBF: Bool {
        get { return get("can_rbf") ?? false }
    }

    var createdAtTs: UInt64 {
        get { return get("created_at_ts") ?? 0 }
    }

    var error: String {
        get { return get("error") ?? String() }
        set { details["error"] = newValue }
    }

    var fee: UInt64 {
        get { return get("fee") ?? 0 }
    }

    var feeRate: UInt64 {
        get { return get("fee_rate" ) ?? 0 }
        set { details["fee_rate"] = newValue }
    }

    var hash: String {
        get { return get("txhash") ?? String() }
    }

    var isSweep: Bool {
        get { return get("is_sweep") ?? false }
    }

    var memo: String {
        get { return get("memo") ?? String() }
        set { details["memo"] = newValue }
    }

    var isLiquid: Bool {
        amounts["btc"] == nil
    }

    static var feeAsset: String {
        AccountsManager.shared.current?.gdkNetwork?.getFeeAsset() ?? ""
    }

    var amounts: [String: Int64] {
        get {
            return get("satoshi") as [String: Int64]? ?? [:]
        }
    }

    var amountsWithoutFees: [(key: String, value: Int64)] {
        if type == .some(.redeposit) {
            return []
        }
        var amounts = Transaction.sort(amounts)
        // OUT transactions in BTC/L-BTC have fee included
        if type == .some(.outgoing) {
            let feeAsset = SessionsManager.current?.gdkNetwork.getFeeAsset()
            amounts = amounts.map { $0.key == feeAsset ? ($0.key, $0.value + Int64(fee)) : $0 }
        }
        return amounts.filter({ $0.value != 0 })
    }

    static func sort(_ dict: [String: Int64]) -> [(key: String, value: Int64)] {
        var sorted = dict.filter { $0.key != feeAsset }.sorted(by: {$0.0 < $1.0 })
        if dict.contains(where: { $0.key == feeAsset }) {
            sorted.insert((key: feeAsset, value: dict[feeAsset]!), at: 0)
        }
        var tAssets: [SortingAsset] = []
        Array(sorted).forEach { asset in
            let info = WalletManager.current?.currentSession?.registry?.info(for: asset.key)
            let hasImage = WalletManager.current?.currentSession?.registry?.hasImage(for: asset.key)
            let tAss = SortingAsset(tag: asset.key, info: info, hasImage: hasImage ?? false, value: asset.value)
            tAssets.append(tAss)
        }
        var oAssets = [(key: String, value: Int64)]()
        tAssets.sort(by: {!$0.hasImage && !$1.hasImage ? $0.info?.ticker != nil && !($1.info?.ticker != nil) : $0.hasImage && !$1.hasImage})
        tAssets.forEach { asset in
            oAssets.append((key:asset.tag, value: asset.value))
        }
        return oAssets
    }

    /// Asset we are trying to send or receive, other than bitcoins for fees
    var defaultAsset: String {
        return Transaction.sort(amounts).filter { $0.key != Transaction.feeAsset }.first?.key ?? Transaction.feeAsset
    }

    var sendAll: Bool {
        get { return get("send_all") ?? false }
        set { details["send_all"] = newValue }
    }

    var size: UInt64 {
        get { return get("transaction_vsize") ?? 0 }
    }

    var type: TransactionType {
        get { TransactionType(rawValue: get("type") ?? "") ?? .outgoing }
    }

    // tx outputs in create transaction
    var transactionOutputs: [[String: Any]]? {
        get { return get("transaction_outputs") }
    }

    // tx outputs in get transaction
    var outputs: [[String: Any]]? {
        get { return get("outputs") }
    }

    // tx inputs in get transaction
    var inputs: [[String: Any]]? {
        get { return get("inputs") }
    }

    var spvVerified: String? {
        get { return get("spv_verified") }
    }

    func date(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(Double(createdAtTs / 1000000)))
        return DateFormatter.localizedString(from: date, dateStyle: dateStyle, timeStyle: timeStyle)
    }

    func hasBlindingData(data: [String: Any]) -> Bool {
        let satoshi = data["satoshi"] as? Int64 ?? 0
        let assetId = data["asset_id"] as? String ?? ""
        let amountBlinder = data["amountblinder"] as? String ?? ""
        let assetBlinder = data["assetblinder"] as? String ?? ""
        return assetId != "" && satoshi != 0 && amountBlinder != "" && assetBlinder != ""
    }

    func txoBlindingData(data: [String: Any], isUnspent: Bool) -> [String: Any] {
        var blindingData = [String: Any]()
        let index = isUnspent ? "vout" : "vin"
        blindingData[index] = data["pt_idx"]
        blindingData["asset_id"] = data["asset_id"]
        blindingData["assetblinder"] = data["assetblinder"]
        blindingData["satoshi"] = data["satoshi"]
        blindingData["amountblinder"] = data["amountblinder"]
        return blindingData
    }

    func txoBlindingString(data: [String: Any]) -> String? {
        if !hasBlindingData(data: data) {
            return nil
        }
        let satoshi = data["satoshi"] as? UInt64 ?? 0
        let assetId = data["asset_id"] as? String ?? ""
        let amountBlinder = data["amountblinder"] as? String ?? ""
        let assetBlinder = data["assetblinder"] as? String ?? ""
        return String(format: "%lu,%@,%@,%@", satoshi, assetId, amountBlinder, assetBlinder)
    }

    func blindingData() -> [String: Any]? {
        var txBlindingData = [String: Any]()
        txBlindingData["version"] = 0
        txBlindingData["txid"] = hash
        txBlindingData["type"] = type
        txBlindingData["inputs"] = inputs?.filter { (data: [String: Any]) -> Bool in
            return hasBlindingData(data: data)
        }.map { (data: [String: Any]) -> [String: Any] in
            return txoBlindingData(data: data, isUnspent: false)
        }
        txBlindingData["outputs"] = outputs?.filter { (data: [String: Any]) -> Bool in
            return hasBlindingData(data: data)
        }.map { (data: [String: Any]) -> [String: Any] in
            return txoBlindingData(data: data, isUnspent: true)
        }
        return txBlindingData
    }

    func blindingUrlString() -> String {
        var blindingUrlString = [String]()
        inputs?.forEach { input in
            if let b = txoBlindingString(data: input) {
                blindingUrlString.append(b)
            }
        }
        outputs?.forEach { output in
            if let b = txoBlindingString(data: output) {
                blindingUrlString.append(b)
            }
        }
        return blindingUrlString.isEmpty ? "" : "#blinded=" + blindingUrlString.joined(separator: ",")
    }
}
