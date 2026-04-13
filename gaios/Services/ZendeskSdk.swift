import Foundation
import SupportSDK
import ZendeskCoreSDK
import gdk
import greenaddress
import core

enum ZendeskErrorRequestType: String {
    case incident
    case feedback
}

struct ZendeskErrorRequest {
    var email: String?
    var error: String?
    var throwable: String? = Thread.callStackSymbols.joined(separator: "\n")
    var network: NetworkSecurityCase?
    var timestamp = Date().timeIntervalSince1970
    var paymentHash: String?
    var message: String?
    var shareLogs: Bool = false
    var shareKeys: Bool = false
    var shareSettings: Bool = false
    var screenName: String?
    var type: ZendeskErrorRequestType = .incident

    let maxLogsSize = 8000

    var hw: String? {
        let account = AccountsRepository.shared.current
        if account?.isLedger ?? false {
            return "ledger_nano_x"
        } else if account?.isJade ?? false {
            switch account?.boardType {
            case .v1, .v1_1:
                return "jade_classic"
            case .v2:
                return "jade_plus"
            case .v2c:
                return "jade_core"
            default:
                return "jade"
            }
        } else {
            return nil
        }
    }
    var subject: String? {
        if type == .feedback {
            return "Feedback from green_ios"
        } else if let screenName = screenName {
            return "Bug report from green_ios in \(screenName)"
        } else {
            return "Bug report from green_ios"
        }
    }
    var accountType: String? {
        guard let network = network else {
            return nil
        }
        if network.lightning {
            return "lightning__green_"
        } else if network.singlesig {
            return "singlesig__green_"
        } else {
            return "multisig_shield__green_"
        }
    }
    func metadata() -> String {
        var result = error ?? ""
        result += "\r\n"
        result += "Timestamp: \(Int(timestamp))\r\n"
        if let nodeId = WalletManager.current?.lightningSession?.nodeId {
            result += "Lightning node id: \(nodeId)\r\n"
            result += "Lightning logged: \(WalletManager.current?.lightningSession?.logged ?? false)\r\n"
        }
        if shareSettings {
            result += "App settings: \r\n"
            result += AppSettings.shared.gdkSettings?.stringify() ?? ""
            result += "\r\n"
        }
        if shareKeys {
            let pubkeys = WalletManager.current?.subaccounts.compactMap { $0.extendedPubkey }.joined(separator: ",")
            let descriptors = WalletManager.current?.subaccounts.compactMap { $0.coreDescriptors?.joined(separator: ",") }.joined(separator: ",")
            result += ["Pubkey", pubkeys ?? "", "Descriptors", descriptors ?? ""].joined(separator: "\r\n")
        }
        return result
    }

    func logs(truncated: Bool) -> String? {
        var logs = metadata()
        if shareLogs {
            let greenLogsFull = logger.export(category: "Green").joined(separator: "\r\n")
            let lightningLogsFull = logger.export(category: "Lightning").joined(separator: "\r\n")
            let lwkLogsFull = logger.export(category: "Lwk").joined(separator: "\r\n")
            if truncated == true {
                logs = cutLogs(head: logs,
                               greenLogs: greenLogsFull,
                               lightningLogs: lightningLogsFull,
                               lwkLogs: lwkLogsFull)
            } else {
                logs += ["Green logs", greenLogsFull, "Lightning logs", lightningLogsFull, "Lwk logs", lwkLogsFull].joined(separator: "\r\n")
            }
        }
        return logs
    }

    func cutLogs(head: String, greenLogs: String, lightningLogs: String, lwkLogs: String) -> String {
        var logs = ""
        var pos = 1
        var validLogs = head

        while logs.utf8.count < maxLogsSize {
            let greenLogs = greenLogs.suffix(pos)
            let lightningLogs = lightningLogs.suffix(pos)
            let lwkLogs = lwkLogs.suffix(pos)
            logs = head + ["Green logs", greenLogs, "Lightning logs", lightningLogs, "Lwk logs", lwkLogs].joined(separator: "\r\n")
            if logs == validLogs {
                return validLogs
            }
            if logs.utf8.count < maxLogsSize {
                validLogs = logs
            }
            pos += 1
        }
        return validLogs
    }
}

class ZendeskSdk {
    static let shared = ZendeskSdk()
    let URL = "https://blockstream.zendesk.com"
    let APPLICATION_ID = "12519480a4c4efbe883adc90777bb0f680186deece244799"
    var isAvailable: Bool { ZENDESK_CLIENT_ID != nil }
    var ZENDESK_CLIENT_ID: String? {
        Bundle.main.infoDictionary?["ZENDESK_CLIENT_ID"] as? String
    }
    var osInfo: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion)
    }
    init() {
        Zendesk.initialize(appId: APPLICATION_ID, clientId: ZENDESK_CLIENT_ID ?? "", zendeskUrl: URL)
        Support.initialize(withZendesk: Zendesk.instance)
    }

    func createNewTicketUrl(
        req: ZendeskErrorRequest
    ) async -> URL? {

        let supportId = await SupportManager.shared.str()
        let countlyId = AnalyticsManager.shared.analyticsUUID

        var components = URLComponents(string: "https://help.blockstream.com/hc/en-us/requests/new")!
        components.queryItems = [
            URLQueryItem(name: "tf_900008231623", value: "ios"),
            URLQueryItem(name: "tf_42657567831833", value: osInfo),
            URLQueryItem(name: "tf_900009625166", value: Bundle.main.versionNumber),
            URLQueryItem(name: "tf_900003758323", value: "green"),
            URLQueryItem(name: "tf_21409433258649", value: req.logs(truncated: true)),
            URLQueryItem(name: "tf_42306364242073", value: countlyId),
            URLQueryItem(name: "tf_42575138597145", value: req.type.rawValue),
            URLQueryItem(name: "tf_23833728377881", value: supportId)
        ]
        if let hw = req.hw {
            components.queryItems! += [URLQueryItem(name: "tf_900006375926", value: hw)]
        }
        if let accountType = req.accountType {
            components.queryItems! += [URLQueryItem(name: "tf_6167739898649", value: accountType)]
        }
        return components.url
    }

    func getCurrentShortDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy_HH-mm-ss"
        return dateFormatter.string(from: Date())
    }

    func uploadLogs(_ text: String, category: String = "Green") async throws -> ZDKUploadResponse {
        let uploadProvider = ZDKUploadProvider()
        let filename = "\(getCurrentShortDate())_\(category).log"
        return try await withCheckedThrowingContinuation { continuation in
            uploadProvider.uploadAttachment(
                text.data(using: .utf8),
                withFilename: filename,
                andContentType: "text/plain",
                callback: { uploadResponse, error in
                    if let uploadResponse = uploadResponse {
                        logger.info("Token: \(uploadResponse.uploadToken ?? "")")
                        logger.info("Attachment: \(uploadResponse.attachment.description)")
                        continuation.resume(returning: uploadResponse)
                    } else {
                        continuation.resume(throwing: error ?? GaError.GenericError(""))
                    }
                })
        }
    }

    func submitNewTicket(
        req: ZendeskErrorRequest
    ) async throws -> String {
        // Set identity
        var identity = Identity.createAnonymous()
        if let email = req.email {
            identity = Identity.createAnonymous(email: email)
        }
        Zendesk.instance?.setIdentity(identity)

        // Setup ticket request
        let request = ZDKCreateRequest()
        request.tags = ["ios", "green"]
        request.subject = req.subject
        request.requestDescription = req.message ?? "{No Message}"
        let supportId = await SupportManager.shared.str()
        let countlyId = AnalyticsManager.shared.analyticsUUID
        var customFields = [
            CustomField(fieldId: 900003758323, value: "green"),
            CustomField(fieldId: 900009625166, value: Bundle.main.versionNumber),
            CustomField(fieldId: 900008231623, value: "ios"),
            CustomField(fieldId: 42657567831833, value: osInfo),
            CustomField(fieldId: 21409433258649, value: req.metadata()),
            CustomField(fieldId: 42306364242073, value: countlyId),
            CustomField(fieldId: 42575138597145, value: req.type.rawValue),
            CustomField(fieldId: 23833728377881, value: supportId)
        ]
        if let hw = req.hw {
            customFields += [CustomField(fieldId: 900006375926, value: hw)]
        }
        if let accountType = req.accountType {
            customFields += [CustomField(fieldId: 6167739898649, value: accountType)]
        }
        request.customFields = customFields

        // Upload log files as attachments
        if req.shareLogs {
            var attachments: [ZDKUploadResponse] = []
            for category in ["Green", "Lightning", "Lwk"] {
                let content = logger.export(category: category).joined(separator: "\n")
                guard !content.isEmpty else { continue }
                if let response = try? await uploadLogs(content, category: category) {
                    attachments.append(response)
                }
            }
            if !attachments.isEmpty {
                request.attachments = attachments
            }
        }

        // Upload ticket
        let provider = ZDKRequestProvider()
        return try await withCheckedThrowingContinuation { continuation in
            provider.createRequest(request) { result, error in
                if let error = error  {
                    logger.error("ZendeskSdk: request error \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    logger.info("ZendeskSdk: request success")
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
