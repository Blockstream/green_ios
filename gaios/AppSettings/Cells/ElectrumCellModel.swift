class ElectrumCellModel {
    var switchTls: Bool
    var serverBTC: String
    var serverLiquid: String
    var serverTestnet: String
    var serverLiquidtestnet: String
    init(switchTls: Bool,
         serverBTC: String,
         serverLiquid: String,
         serverTestnet: String,
         serverLiquidtestnet: String
    ) {
        self.switchTls = switchTls
        self.serverBTC = serverBTC
        self.serverLiquid = serverLiquid
        self.serverTestnet = serverTestnet
        self.serverLiquidtestnet = serverLiquidtestnet
    }
}
