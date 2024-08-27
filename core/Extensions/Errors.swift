import Foundation
import BreezSDK
import gdk
import greenaddress
import hw
import lightning

extension Error {

    public func description() -> String? {
        if let authError = self as? AuthenticationTypeHandler.AuthError {
            return authError.localizedDescription
        }
        if let hwError = self as? HWError {
            switch hwError {
            case HWError.Abort(let txt), HWError.Declined(let txt), HWError.Disconnected(let txt):
                return txt
            case .URLError(_):
                return "Invalid URL"
            case .InvalidResponse(_):
                return "Invalid Response"
            }
        }
        if let swError = self as? BleLedgerConnection.SWError {
            return swError.description()
        }

        if let _ = self as? BleLedgerConnection.LedgerError {
            return "id_operation_failed"
        }
        if let loginError = self as? LoginError {
            switch loginError {
            case LoginError.connectionFailed:
                return "id_connection_failed"
            case LoginError.failed:
                return "id_login_failed"
            case LoginError.walletNotFound:
                return "id_wallet_not_found"
            case LoginError.hostUnblindingDisabled(let txt):
                return txt ?? "id_operation_failed"
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
                return txt ?? "id_operation_failed"
            case .ReconnectError(_):
                return "Reconnect Error"
            case .SessionLost(_):
                return "Session Error"
            case .TimeoutError(_):
                return "Timeout Error"
            }
        }
        if let resolverError = self as? TwoFactorCallError {
            switch resolverError {
            case TwoFactorCallError.cancel(let txt),
                TwoFactorCallError.failure(let txt):
                if txt.isEmpty {
                    return nil
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
            return breezError.description()
        }
        if let breezError = self as? BreezSDK.SendOnchainError {
            return breezError.description()
        }
        if let breezError = self as? BreezSDK.SendPaymentError {
            return breezError.description()
        }
        if let breezError = self as? BreezSDK.ReceiveOnchainError {
            return breezError.description()
        }
        if let breezError = self as? BreezSDK.ReceivePaymentError {
            return breezError.description()
        }
        if let breezError = self as? BreezSDK.LnUrlPayError {
            return breezError.description()
        }
        if let breezError = self as? BreezSDK.LnUrlAuthError {
            return breezError.description()
        }
        if let breezError = self as? BreezSDK.ConnectError {
            return breezError.description()
        }
        return nil
    }
}
