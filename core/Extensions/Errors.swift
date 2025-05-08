import Foundation
import BreezSDK
import gdk
import greenaddress
import hw
import lightning

extension Error {

    public func description() -> String {
        if let authError = self as? AuthenticationTypeHandler.AuthError {
            return authError.localizedDescription
        }
        if let hwError = self as? HWError {
            switch hwError {
            case HWError.Abort(let txt), HWError.Declined(let txt):
                return txt
            case HWError.Disconnected(_):
                return "id_disconnect"
            case .URLError:
                return "id_invalid_url"
            case .InvalidResponse:
                return "Invalid Response"
            case .NoNewFirmwareFound:
                return "Firmware up to date"
            }
        }
        if let swError = self as? BleLedgerConnection.SWError {
            return swError.description()
        }

        if let _ = self as? BleLedgerConnection.LedgerError {
            return "id_operation_failure"
        }
        if let loginError = self as? LoginError {
            switch loginError {
            case LoginError.connectionFailed(let txt):
                return txt ?? "id_connection_failed"
            case LoginError.failed:
                return "id_login_failed"
            case LoginError.walletNotFound:
                return "id_wallet_not_found"
            case LoginError.hostUnblindingDisabled(let txt):
                return txt ?? "id_operation_failure"
            case LoginError.walletMismatch( _):
                return "Wallet mismatch"
            case LoginError.walletsJustRestored(_):
                return "id_wallet_already_restored"
            case LoginError.invalidMnemonic(_):
                return "id_invalid_mnemonic"
            }
        }
        if let gdkError = self as? GaError {
            switch gdkError {
            case GaError.NotAuthorizedError:
                return "Not Authorized Error"
            case GaError.GenericError(let txt):
                return txt ?? "id_operation_failure"
            case .ReconnectError:
                return "Reconnect Error"
            case .SessionLost:
                return "Session Error"
            case .TimeoutError:
                return "Timeout Error"
            }
        }
        if let resolverError = self as? TwoFactorCallError {
            switch resolverError {
            case TwoFactorCallError.cancel(let txt),
                TwoFactorCallError.failure(let txt):
                if txt.isEmpty {
                    return "id_operation_failure"
                }
                return txt
            }
        }
        if let resolverError = self as? TransactionError {
            switch resolverError {
            case .invalid(let txt):
                return txt
            case .failure(let txt, let paymentHash):
                return "\(txt) \(paymentHash)"
            }
        }
        if let breezError = self as? BreezSDK.SdkError {
            return breezError.description() ?? "Sdk error"
        }
        if let breezError = self as? BreezSDK.SendOnchainError {
            return breezError.description() ?? "Send onchain error"
        }
        if let breezError = self as? BreezSDK.SendPaymentError {
            return breezError.description() ?? "Send payment error"
        }
        if let breezError = self as? BreezSDK.ReceiveOnchainError {
            return breezError.description() ?? "Receive onchain error"
        }
        if let breezError = self as? BreezSDK.ReceivePaymentError {
            return breezError.description() ?? "Receive payment error"
        }
        if let breezError = self as? BreezSDK.LnUrlPayError {
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.LnUrlAuthError {
            return breezError.description() ?? "LN url auth error"
        }
        if let breezError = self as? BreezSDK.ConnectError {
            return breezError.description() ?? "Connection error"
        }
        return "id_operation_failure"
    }
}
