import Foundation
import BreezSDK
import gdk
import greenaddress
import hw
import lightning
import LiquidWalletKit
import core

extension Error {

    public func description() -> String {
        if let error = self as? SendFlowError {
            return error.description().localized
        }
        if let authError = self as? AuthenticationTypeHandler.AuthError {
            return authError.localizedDescription
        }
        if let hwError = self as? HWError {
            switch hwError {
            case HWError.Abort(let txt), HWError.Declined(let txt):
                return txt
            case HWError.Disconnected(_):
                return "id_your_device_was_disconnected"
            case .URLError:
                return "id_invalid_url"
            case .InvalidResponse:
                return "id_invalid_response"
            case .NoNewFirmwareFound:
                return "id_firmware_up_to_date"
            case .Rebooted(_):
                return "id_device_rebooted_reconnecting"
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
                return "id_wallet_mismatch"
            case LoginError.walletsJustRestored(_):
                return "id_wallet_already_restored"
            case LoginError.invalidMnemonic(_):
                return "id_invalid_mnemonic"
            }
        }
        if let gdkError = self as? GaError {
            switch gdkError {
            case GaError.NotAuthorizedError:
                return "id_not_authorized"
            case GaError.GenericError(let txt):
                return txt ?? "id_operation_failure"
            case .ReconnectError:
                return "id_reconnect_error"
            case .SessionLost:
                return "id_session_expired"
            case .TimeoutError:
                return "id_timeout"
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
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.SendOnchainError {
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.SendPaymentError {
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.ReceiveOnchainError {
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.ReceivePaymentError {
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.LnUrlPayError {
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.LnUrlAuthError {
            return breezError.description() ?? "id_operation_failure"
        }
        if let breezError = self as? BreezSDK.ConnectError {
            return breezError.description() ?? "id_connection_failed"
        }
        if let error = self as? LwkError {
            return error.description()
        }
        return self.localizedDescription
    }
}
