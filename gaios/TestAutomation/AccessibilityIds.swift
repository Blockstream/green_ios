import Foundation

struct AccessibilityIds {
    struct KeyboardView {
        static let done = "done_btn"
    }
    struct CommonElements {
        static let btnHeaderTapOpenDrawer = "btn_header_tab_open_drawer"
        static let ctaViewBuy = "cta_view_buy"
        static let ctaViewSend = "cta_view_send"
        static let ctaViewReceive = "cta_view_receive"
        static func cellAssetSelect(_ idx: Int) -> String {
            return "cell_asset_select_index_\(idx)"
        }
        static func cellCountrySelect(_ idx: Int) -> String {
            return "cell_country_select_index_\(idx)"
        }
        static func cellWalletSelect(_ idx: Int) -> String {
            return "cell_wallet_select_index_\(idx)"
        }
    }
    struct GetStartedOnBoardScreen {
        static let view = "view_get_started_on_board"
        static let btnOptionsMenu = "btn_get_started_on_board_options_menu"
        static let btnGetStarted = "btn_get_started_on_board_get_started"
    }
    struct DialogAnalyticsScreen {
        static let view = "view_dialog_analytics"
        static let btnAllowDataCollection = "btn_dialog_analytics_allow_data_collection"
        static let btnDenyDataCollection = "btn_dialog_analytics_deny_data_collection"
    }
    struct AppSettingsScreen {
        static let view = "view_app_settings"
        static let switchEnableTestnet = "switch_app_settings_enable_testnet"
        static let switchEnableExperimental = "switch_app_settings_enable_experimental"
    }
    struct SetupNewScreen {
        static let view = "view_setup_new"
        static let btnSetUpMobileWallet = "btn_setup_new_setup_mobile_wallet"
    }
    struct SetPinScreen {
        static let view = "view_set_pin"
        static func btnPinNumber(_ number: Int) -> String {
            return "btn_set_pin_\(number)"
        }
        static let btnCancel = "btn_set_pin_cancel"
        static let btnUndo = "btn_set_pin_undo"
        static let btnConfirm = "btn_set_pin_confirm"
    }
    struct HomeScreen {
        static let view = "view_home"
        // static let btnRenameWallet = "btn_home_rename_wallet"
        // static let btnDeleteWallet = "btn_home_delete_wallet"
        static let btnSetUpNewWallet = "btn_home_setup_new_wallet"
    }
    struct DrawerScreen {
        static let view = "view_drawer"
        static let btnBack = "btn_drawer_back"
        static let btnSetUpNewWallet = "btn_drawer_setup_new_wallet"
    }
    struct WOSetupScreen {
        static let view = "view_wo_setup"
        static let textfieldUsername = "textfield_wo_setup_username"
        static let textfieldPassword = "textfield_wo_setup_password"
        static let btnNext = "btn_wo_setup_next"
    }
    struct BuyBTCScreen {
        static let view = "view_buy_btc"
        static let btnBuyBTCOpenCountry = "btn_buy_btc_open_country"
    }
    struct SelectCountryScreen {
        static let view = "view_select_country"
        static let viewSelectCountryHandle = "view_select_country_handle"
    }
}
