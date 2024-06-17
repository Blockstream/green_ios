import Foundation
import RiveRuntime
import core

enum Constants {
    static let mnemonicSizeDefault = MnemonicSize._12.rawValue
    static let wordsPerPage = 6
    static let wordsPerQuiz = 4
    static let electrumPrefix = "electrum-"
    static let trxPerPage: UInt32 = 30
    static let jadeAnimInterval: Double = 6.0
}

enum ExternalUrls {
    static let otaReadMore = URL(string: "https://blockstream.zendesk.com/hc/en-us/articles/4408030503577")!
    static let receiveTransactionHelp = URL(string: "https://help.blockstream.com/hc/en-us/articles/900004651103-How-do-I-receive-assets-on-Blockstream-Green-")!
    static let jadeNeedHelp = URL(string: "https://help.blockstream.com/hc/en-us/articles/4406185830041")!
    static let jadeMoreInfo = URL(string: "https://blockstream.zendesk.com/hc/en-us/articles/4412006238617")!
    static let mnemonicNotWorking = URL(string: "https://help.blockstream.com/hc/en-us/articles/900001388566-Why-is-my-mnemonic-backup-not-working-")!
    static let analyticsReadMore = URL(string: "https://blockstream.zendesk.com/hc/en-us/articles/5988514431897")!
    static let passphraseReadMore = URL(string: "https://help.blockstream.com/hc/en-us/articles/8712301763737")!

    static let aboutBlockstreamGreenWebSite = URL(string: "https://blockstream.com/green/")!
    static let aboutBlockstreamTwitter = URL(string: "https://twitter.com/Blockstream")!
    static let aboutBlockstreamLinkedIn = URL(string: "https://www.linkedin.com/company/blockstream")!
    static let aboutBlockstreamFacebook = URL(string: "https://www.facebook.com/Blockstream")!
    static let aboutBlockstreamTelegram = URL(string: "https://t.me/blockstream_green")!
    static let aboutBlockstreamGitHub = URL(string: "https://github.com/Blockstream")!
    static let aboutBlockstreamYouTube = URL(string: "https://www.youtube.com/channel/UCZNt3fZazX9cwWcC9vjDJ4Q")!

    static let aboutHelpCenter = URL(string: "https://help.blockstream.com/hc/en-us/categories/900000056183-Blockstream-Green/")!
    static let aboutTermsOfService = URL(string: "https://blockstream.com/green/terms/")!
    static let aboutPrivacyPolicy = URL(string: "https://blockstream.com/green/privacy/")!

    static let jadeTroubleshoot = URL(string: "https://help.blockstream.com/hc/en-us/articles/4406185830041-Why-is-my-Blockstream-Jade-not-connecting-over-Bluetooth-")!
    static let blockstreamStore = URL(string: "https://store.blockstream.com/product/jade-hardware-wallet/")!
    static let helpReceiveCapacity = "https://help.blockstream.com/hc/en-us/articles/18788499177753"
    static let helpReceiveFees = "https://help.blockstream.com/hc/en-us/articles/18788578831897"
    static let helpRecoveryTransactions = "https://help.blockstream.com/hc/en-us/articles/900004249546-The-upgrade-from-nLockTime-to-CheckSequenceVerify"
    static let pinServerSupport = "https://help.blockstream.com/hc/en-us/requests/new?tf_900008231623=ios&tf_subject=Non-default%20PIN%20server&&tf_900003758323=blockstream_jade&tf_900006375926=jade&tf_900009625166="
    static let lightningJadeHelp = "https://help.blockstream.com/hc/en-us/articles/27446807737497"
    static let helpBlockstream = URL(string: "https://help.blockstream.com")!
    static let masterBlindingKey = URL(string: "https://help.blockstream.com/hc/en-us/articles/4403675941017-What-are-the-implications-of-exporting-the-master-blinding-key")!
    static let reEnable2faLearnMore = URL(string: "https://help.blockstream.com/hc/en-us/articles/900001391763-How-does-Blockstream-Green-s-2FA-multisig-protection-work#h_01HRYKB9YRHWX02REXYY34VPV9")!
    static let feesInfo = URL(string: "https://help.blockstream.com/hc/en-us/articles/4412578550809")!
    static let scanQRFixIssues = URL(string: "https://help.blockstream.com/hc/en-us/articles/20427378059417-Fix-issues-scanning-QR-codes")!
    static let qrModeScanWithJade = URL(string: "https://blockstream.zendesk.com/hc/en-us/articles/28264425434265")!
    static let qrModeAirGapUsage = URL(string: "https://help.blockstream.com/hc/en-us/sections/10426339090713-Air-gapped-Usage")!
    static let qrModeAirGapSupport = URL(string: "https://help.blockstream.com/hc/en-us/articles/20272957303577-Add-Jade-to-a-QR-supported-app")!
}

enum RiveModel {
    static let animationWallet = RiveViewModel(fileName: "Illustration Wallet")
    static let animationJade1 = RiveViewModel(fileName: "Jade 01 - Adjusted")
    static let animationJade2 = RiveViewModel(fileName: "Jade 02 - Adjusted")
    static let animationJade3 = RiveViewModel(fileName: "Jade 03 - Faster + BG + Side Scroll")
    static let animationJadeFirmware = RiveViewModel(fileName: "Jade 04 - Faster + BG + Refresh")
    static let animationArchived = RiveViewModel(fileName: "Illustration Account Archived")
    static let animationCheckList = RiveViewModel(fileName: "Illustration Checklist")
    static let animationRocket = RiveViewModel(fileName: "Illustration Rocket")
    static let animationLightningTransaction = RiveViewModel(fileName: "Illustration Lightning Transaction")
    static let animationCheckMark = RiveViewModel(fileName: "Illustration Checkmark")
}
