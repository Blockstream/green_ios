public extension AnalyticsManager {

    static let countlyRemoteConfigAppReview = "app_review"
    static let countlyRemoteConfigBanners = "banners"
    static let countlyRemoteConfigAssets = "liquid_assets"
    static let countlyRemoteConfigPromos = "promos"
    static let countlyRemoteConfigFeatureOnOffRamps = "feature_on_off_ramps"
    static let countlyRemoteConfigBuyDefaultValues = "buy_default_values"
    static let countlyRemoteConfigEnableBuyIosUk = "enable_buy_ios_uk"
    
    static let strNetworks = "wallet_networks"
    static let strNetwork = "account_network"
    static let strSecurity = "security"
    static let strAccountType = "account_type"
    static let str2fa = "2fa"
    static let strMethod = "method"
    static let strEphemeralBip39 = "ephemeral_bip39"
    static let strPage = "page"
    static let strBrand = "brand"
    static let strModel = "model"
    static let strFirmware = "firmware"
    static let strConnection = "connection"
    static let strError = "error"
    static let strFlow = "flow"

    static let strIsUri = "is_uri"
    static let strIsQR = "is_qr"

    static let strTransactionType = "transaction_type"
    static let strAddressInput = "address_input"
    static let strSendAll = "send_all"
    static let strWithMemo = "with_memo"
    static let strNodeId = "node_id"

    static let strWalletFunded = "wallet_funded"
    static let strAccounts = "accounts"
    static let strAccountsTypes = "accounts_types"
    static let strAccountsFunded = "accounts_funded"

    static let strAppSettings = "app_settings"

    static let strUserPropertyTotalWallets = "total_wallets"

    static let strUserPropertyBitcoinWallets = "bitcoin_wallets"
    static let strUserPropertyBitcoinSinglesigWallets = "bitcoin_singlesig_wallets"
    static let strUserPropertyBitcoinMultisigWallets = "bitcoin_multisig_wallets"

    static let strUserPropertyLiquidWallets = "liquid_wallets"
    static let strUserPropertyLiquidSinglesigWallets = "liquid_singlesig_wallets"
    static let strUserPropertyLiquidMultisigWallets = "liquid_multisig_wallets"

    static let strTor = "tor"
    static let strProxy = "proxy"
    static let strTestnet = "testnet"
    static let strElectrumServer = "electrum_server"
    static let strSpv = "spv"

    static let strBle = "BLE"

    static let strShare = "share"
    static let strCopy = "copy"

    static let strSinglesig = "singlesig"
    static let strMultisig = "multisig"

    static let strAnalyticsGroup = "analytics"
    static let strCountlyGroup = "countly"

    static let strType = "type"
    static let strMedia = "media"
    static let strScreen = "screen"

    static let strSelectedConfig = "selected_config"
    static let strSelectedDelta = "selected_delta"
    static let strSelectedVersion = "selected_version"

    static let strPromoId = "promo_id"
    static let strPromoScreen = "screen"

    enum OnBoardFlow: String {
        case strCreate = "create"
        case strRestore = "restore"
        case watchOnly = "watch_only"
    }

    enum LoginType: String {
        case pin = "pin"
        case biometrics = "biometrics"
        case watchOnly = "watch_only"
        case hardware = "hardware"
    }
    static let maxOffsetProduction = 12 * 60 * 60 * 1000 // 12 hours
    static let maxOffsetDevelopment = 30 * 60 * 1000 // 30 mins

    static let ratingWidgetId = "63a5b28802962d16dabcd451"

    enum NtwTypeDescriptor: String {
        /// mainnet / liquid / mainnet-mixed / testnet / testnet-liquid / testnet-mixed
        case mainnet
        case liquid
        case mainnetMixed = "mainnet-mixed"
        case testnet
        case testnetLiquid = "testnet-liquid"
        case testnetMixed = "testnet-mixed"
    }

    enum SecTypeDescriptor: String {
        /// security: singlesig / multisig / lightning / single-multi / single-light / multi-light / single-multi-light
        case single
        case singlesig
        case multi
        case multisig
        case light
        case lightning
    }

    enum QrScanScreen: String {
        case addAccountPK = "AddAccountPublicKey"
        case onBoardRecovery = "OnBoardEnterRecovery"
        case onBoardWOCredentials = "OnBoardWatchOnlyCredentials"
        case walletOverview = "WalletOverview"
        case send = "Send"
    }
}
