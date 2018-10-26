#include "include/twofactor.hpp"

#include "assertion.hpp"
#include "boost_wrapper.hpp"
#include "containers.hpp"
#include "exception.hpp"
#include "ga_strings.hpp"
#include "ga_tx.hpp"
#include "ga_wally.hpp"
#include "transaction_utils.hpp"
#include "twofactor_calls.hpp"
#include "xpub_hdkey.hpp"

namespace {
// Server gives 3 attempts to get the twofactor code right before it's invalidated
static const uint32_t TWO_FACTOR_ATTEMPTS = 3;
static const std::string CHALLENGE_PREFIX("greenaddress.it      login ");

// Return true if the error represents 'two factor authentication required'
static bool is_twofactor_invalid_code_error(const autobahn::call_error& e)
{
    return ga::sdk::get_error_details(e).second == "Invalid Two Factor Authentication Code";
}

static auto get_xpub(const std::string& bip32_xpub_str)
{
    const auto hdkey = ga::sdk::bip32_public_key_from_bip32_xpub(bip32_xpub_str);
    return ga::sdk::make_xpub(hdkey.get());
}

static auto get_paths_json(bool include_root = true)
{
    std::vector<nlohmann::json> paths;
    if (include_root) {
        paths.emplace_back(std::vector<uint32_t>());
    }
    return paths;
}

// FIXME: Belongs in xpubs or signer
static auto get_subaccount_path(uint32_t subaccount)
{
    if (subaccount == 0) {
        return std::vector<uint32_t>();
    } else {
        return std::vector<uint32_t>{ ga::sdk::harden(3), ga::sdk::harden(subaccount) };
    }
}

} // namespace

//
// Common auth handling
//
GA_twofactor_call::GA_twofactor_call(
    ga::sdk::session& session, const std::string& action, const nlohmann::json& hw_device)
    : m_session(session)
    , m_methods(hw_device.is_null() ? session.get_enabled_twofactor_methods() : std::vector<std::string>())
    , m_action(action)
    , m_state(m_methods.empty() && hw_device.is_null() ? state_type::make_call : state_type::request_code)
    , m_attempts_remaining(TWO_FACTOR_ATTEMPTS)
    , m_hw_device(hw_device.is_null() ? hw_device : hw_device.at("device"))
{
}

void GA_twofactor_call::set_error(const std::string& error_message)
{
    m_state = state_type::error;
    m_error = error_message;
}

void GA_twofactor_call::request_code(const std::string& method)
{
    request_code_impl(method);
    m_attempts_remaining = TWO_FACTOR_ATTEMPTS;
}

void GA_twofactor_call::request_code_impl(const std::string& method)
{
    GA_SDK_RUNTIME_ASSERT(m_state == state_type::request_code);

    // For gauth request code is a no-op
    if (method != "gauth") {
        m_session.twofactor_request_code(method, m_action, m_twofactor_data);
    }

    m_method = method;
    m_state = state_type::resolve_code;
}

void GA_twofactor_call::resolve_code(const std::string& code)
{
    GA_SDK_RUNTIME_ASSERT(m_state == state_type::resolve_code);
    m_code = code;
    m_state = state_type::make_call;
}

void GA_twofactor_call::operator()()
{
    GA_SDK_RUNTIME_ASSERT(m_state == state_type::make_call);
    try {
        if (m_code.empty() || m_method.empty()) {
            if (!m_twofactor_data.is_null()) {
                // Remove any previous auth attempts
                m_twofactor_data.erase("method");
                m_twofactor_data.erase("code");
            }
        } else {
            m_twofactor_data["method"] = m_method;
            m_twofactor_data["code"] = m_code;
        }
        m_state = call_impl();
    } catch (const autobahn::call_error& e) {
        if (is_twofactor_invalid_code_error(e)) {
            // The caller entered the wrong code
            // FIXME: Go back to resolve code if the methods time limit is up
            // FIXME: If we are rate limited, move to error with a message
            if (m_method != "gauth" && --m_attempts_remaining == 0) {
                // No more attempts left.
                // Caller should request another code/choose another method
                m_state = state_type::request_code;
            } else {
                // Caller should try entering the code again
                m_state = state_type::resolve_code;
            }
        } else {
            const auto& error_message = ga::sdk::get_error_details(e).second;
            set_error(error_message.empty() ? std::string(e.what()) : error_message);
            m_state = state_type::error;
        }
    }
}

nlohmann::json GA_twofactor_call::get_status() const
{
    GA_SDK_RUNTIME_ASSERT(m_state == state_type::error || m_error.empty());
    const bool is_hw_action = !m_hw_device.is_null();

    std::string status_str;
    nlohmann::json status;

    switch (m_state) {
    case state_type::request_code:
        GA_SDK_RUNTIME_ASSERT(!is_hw_action);

        // Caller should ask the user to pick 2fa and request a code
        status_str = "request_code";
        status["methods"] = m_methods;
        break;
    case state_type::resolve_code:
        status_str = "resolve_code";
        if (is_hw_action) {
            // Caller must interact with the hardware and return
            // the returning data to us
            status["method"] = m_hw_device.at("name");
            status["required_data"] = m_twofactor_data;
        } else {
            // Caller should resolve the code the user has entered
            status["method"] = m_method;
            if (m_method != "gauth") {
                status["attempts_remaining"] = m_attempts_remaining;
            }
        }
        break;
    case state_type::make_call:
        // Caller should make the call
        status_str = "call";
        break;
    case state_type::done:
        // Caller should destroy the call and continue
        status_str = "done";
        status["result"] = m_result;
        break;
    case state_type::error:
        // Caller should handle the error
        status_str = "error";
        status["error"] = m_error;
        break;
    }
    GA_SDK_RUNTIME_ASSERT(!status_str.empty());
    status["status"] = status_str;
    status["action"] = m_action;
    status["device"] = m_hw_device;
    return status;
}

//
// Register
//
GA_register_call::GA_register_call(
    ga::sdk::session& session, const nlohmann::json& hw_details, const std::string& user_agent)
    : GA_twofactor_call(session, "get_xpubs", hw_details)
    , m_user_agent(user_agent)
{
    // To register, we need the master xpub to identify the wallet,
    // and the registration xpub to compute the gait_path.
    m_state = state_type::resolve_code;
    m_twofactor_data = { { "action", m_action }, { "device", m_hw_device } };
    auto paths = get_paths_json();
    paths.emplace_back(std::vector<uint32_t>{ ga::sdk::harden(0x4741) });
    m_twofactor_data["paths"] = paths;
}

GA_twofactor_call::state_type GA_register_call::call_impl()
{
    const nlohmann::json args = nlohmann::json::parse(m_code);
    const std::vector<std::string> xpubs = args.at("xpubs");
    const auto master_xpub = get_xpub(xpubs.at(0));

    const auto master_chain_code_hex = ga::sdk::hex_from_bytes(master_xpub.first);
    const auto master_pub_key_hex = ga::sdk::hex_from_bytes(master_xpub.second);

    // Get our gait path xpub and compute gait_path from it
    const auto gait_xpub = get_xpub(xpubs.at(1));
    const auto gait_path_hex = ga::sdk::hex_from_bytes(ga::sdk::ga_pubkeys::get_gait_path_bytes(gait_xpub));

    m_session.register_user(master_pub_key_hex, master_chain_code_hex, gait_path_hex, m_user_agent);
    return state_type::done;
}

//
// Login
//
GA_login_call::GA_login_call(ga::sdk::session& session, const nlohmann::json& hw_details, const std::string& user_agent)
    : GA_twofactor_call(session, "get_xpubs", hw_details)
    , m_user_agent(user_agent)
{
    // We first need the challenge, so ask the caller for the master pubkey.
    m_state = state_type::resolve_code;
    set_data("get_xpubs");
    m_twofactor_data["paths"] = get_paths_json();
}

GA_twofactor_call::state_type GA_login_call::call_impl()
{
    const nlohmann::json args = nlohmann::json::parse(m_code);

    if (m_action == "get_xpubs") {
        const std::vector<std::string> xpubs = args.at("xpubs");

        if (m_challenge.empty()) {
            // Compute the challenge with the mastre pubkey
            const auto master_xpub = get_xpub(xpubs.at(0));
            const auto btc_version = m_session.get_network_parameters().btc_version();
            m_challenge = m_session.get_challenge(ga::sdk::address_from_xpub(btc_version, master_xpub));

            // Ask the caller to sign the challenge
            set_data("sign_message");
            m_twofactor_data["message"] = CHALLENGE_PREFIX + m_challenge;
            m_twofactor_data["path"] = std::vector<uint32_t>{ 0x4741b11e };
            return state_type::resolve_code;
        } else {
            // Register the xpub for each of our subaccounts
            m_session.register_subaccount_xpubs(xpubs);
            return state_type::done;
        }
    } else if (m_action == "sign_message") {
        // Log in and set up the session
        m_session.authenticate(args.at("signature"), "GA", std::string(), m_user_agent, m_hw_device);

        // Ask the caller for the xpubs for each subaccount
        std::vector<nlohmann::json> paths;
        for (const auto sa : m_session.get_subaccounts()) {
            // FIXME: Cache master xpub from above for subaccount 0
            // rather than asking the hardware again.
            paths.emplace_back(get_subaccount_path(sa["pointer"]));
        }
        set_data("get_xpubs");
        m_twofactor_data["paths"] = paths;
        return state_type::resolve_code;
    }
    return state_type::done;
}

void GA_login_call::set_data(const std::string& action)
{
    m_action = action;
    m_twofactor_data = { { "action", m_action }, { "device", m_hw_device } };
}

//
// Sign tx
//
GA_sign_transaction_call::GA_sign_transaction_call(
    ga::sdk::session& session, const nlohmann::json& hw_details, const nlohmann::json& tx_details)
    : GA_twofactor_call(session, "sign_tx", hw_details)
    , m_tx_details(tx_details)
{
    // Compute the data we need for the hardware to sign the transaction
    m_state = state_type::resolve_code;

    m_twofactor_data = { { "action", m_action }, { "device", m_hw_device }, { "transaction", tx_details } };

    // We need the inputs, augmented with types, scripts and paths
    const auto signing_inputs = ga::sdk::get_ga_signing_inputs(tx_details);
    std::set<std::string> addr_types;
    for (const auto input : signing_inputs) {
        const auto& addr_type = input.at("address_type");
        GA_SDK_RUNTIME_ASSERT(!addr_type.empty()); // Must be spendable by us
        addr_types.insert(addr_type.get<std::string>());
    }
    if (addr_types.find(ga::sdk::address_type::p2pkh) != addr_types.end()) {
        // FIXME: Use the software signer to sign sweep txs
        GA_SDK_RUNTIME_ASSERT(false);
    }
    m_twofactor_data["signing_address_types"] = std::vector<std::string>(addr_types.begin(), addr_types.end());
    m_twofactor_data["signing_inputs"] = signing_inputs;
}

GA_twofactor_call::state_type GA_sign_transaction_call::call_impl()
{
    // FIXME: sign
    return state_type::done;
}

//
// Enable 2FA
//
GA_change_settings_twofactor_call::GA_change_settings_twofactor_call(
    ga::sdk::session& session, const std::string& method_to_update, const nlohmann::json& details)
    : GA_twofactor_call(session, "enable_2fa")
    , m_current_config(session.get_twofactor_config())
    , m_method_to_update(method_to_update)
    , m_details(details)
    , m_enabling(m_details.value("enabled", true))
{
    GA_SDK_RUNTIME_ASSERT(m_current_config.find(method_to_update) != m_current_config.end());

    const auto& current_subconfig = m_current_config[method_to_update];

    const bool set_email = method_to_update == "email" && !m_enabling && m_details.value("confirmed", false);

    if (!set_email && current_subconfig.value("enabled", !m_enabling) == m_enabling) {
        // Caller is attempting to enable or disable when thats already the current state
        set_error(method_to_update + " is already " + (m_enabling ? "enabled" : "disabled"));
        return;
    }

    // The data associated with method_to_update e.g. email, phone etc
    const std::string data = ga::sdk::json_get_value(m_details, "data");

    if (m_enabling) {
        if (method_to_update == "gauth") {
            // For gauth the user must pass in the current seed returned by the
            // server.
            // FIXME: Allow the user to specify their own seed in the future.
            if (data != ga::sdk::json_get_value(current_subconfig, "data")) {
                set_error(ga::sdk::res::id_inconsistent_data_provided_for);
                return;
            }
        }
        m_twofactor_data = { { "method", m_method_to_update } };
    } else {
        if (set_email) {
            // The caller set confirmed=true but enabled=false: they only want
            // to set the email associated with twofactor but not enable it for 2fa.
            // This is useful since notifications and 2fa currently share the
            // same 2fa email address.
            m_action = "set_email";
            m_twofactor_data = { { "address", data } };
        } else {
            m_action = "disable_2fa";
            m_twofactor_data = { { "method", method_to_update } };
        }
    }
}

GA_twofactor_call::state_type GA_change_settings_twofactor_call::on_init_done(const std::string& new_action)
{
    // The user has either:
    // 1) Skipped entering any 2fa so far because they have none enabled, OR
    // 2) Entered the 2fa details of another method to allow the new method to be enabled
    // So, we now request the user enters the code for the method they are enabling
    // (which means restricting their 2fa choice for entering the code to this method)
    m_method = m_method_to_update;
    m_action = new_action + m_method;
    m_methods = { { m_method_to_update } };
    // Move to prompt the user for the code for the method they are enabling
    m_gauth_data = m_twofactor_data;
    m_twofactor_data = nlohmann::json();
    return state_type::resolve_code;
}

GA_twofactor_call::state_type GA_change_settings_twofactor_call::call_impl()
{
    if (m_action == "set_email") {
        const std::string data = ga::sdk::json_get_value(m_details, "data");
        m_session.set_email(data, m_twofactor_data);
        // Move to activate email
        return on_init_done("activate_");
    } else if (m_action == "activate_email") {
        const std::string data = ga::sdk::json_get_value(m_details, "data");
        m_session.activate_email(m_code);
        return state_type::done;
    } else if (m_action == "enable_2fa") {
        if (m_method_to_update != "gauth") {
            // gauth doesn't have an init_enable step
            const std::string data = ga::sdk::json_get_value(m_details, "data");
            m_session.init_enable_twofactor(m_method_to_update, data, m_twofactor_data);
        }
        // Move to enable the 2fa method
        return on_init_done("enable_");
    } else if (boost::algorithm::starts_with(m_action, "enable_")) {
        // The user has authorized enabling 2fa (if required), so enable the
        // method using its code (which proves the user got a code from the
        // method being enabled)
        if (m_method_to_update == "gauth") {
            m_session.enable_gauth(m_code, m_gauth_data);
        } else {
            m_session.enable_twofactor(m_method_to_update, m_code);
        }
        return state_type::done;
    } else if (m_action == "disable_2fa") {
        m_session.disable_twofactor(m_method_to_update, m_twofactor_data);
        // For gauth, we must reset the sessions 2fa data since once it is
        // disabled, the server must create a new secret (which it only
        // does on fetching 2fa config). Without this a subsequent re-enable
        // will fail.
        // FIXME: The server should return the new secret/the user should be
        // able to supply their own
        const bool reset_cached = m_method_to_update == "gauth";
        m_result = m_session.get_twofactor_config(reset_cached).at(m_method_to_update);
        return state_type::done;
    } else {
        GA_SDK_RUNTIME_ASSERT(false);
        __builtin_unreachable();
    }
}

//
// Change limits
//
GA_change_limits_call::GA_change_limits_call(ga::sdk::session& session, const nlohmann::json& details)
    : GA_twofactor_call(session, "change_tx_limits")
    , m_limit_details(details)
    , m_is_decrease(m_methods.empty() ? false : m_session.is_spending_limits_decrease(details))
{
    if (m_is_decrease) {
        m_state = state_type::make_call; // Limit decreases do not require 2fa
    }
}

void GA_change_limits_call::request_code(const std::string& method)
{
    // If we are requesting a code, then our limits changed elsewhere and
    // this is not a limit decrease
    m_is_decrease = false;
    GA_twofactor_call::request_code(method);
}

GA_twofactor_call::state_type GA_change_limits_call::call_impl()
{
    m_session.change_settings_limits(m_limit_details, m_is_decrease ? nlohmann::json() : m_twofactor_data);
    return state_type::done;
}

//
// Remove account
//
GA_remove_account_call::GA_remove_account_call(ga::sdk::session& session)
    : GA_twofactor_call(session, "remove_account")
{
}

GA_twofactor_call::state_type GA_remove_account_call::call_impl()
{
    m_session.remove_account(m_twofactor_data);
    return state_type::done;
}

//
// Send transaction
//
GA_send_call::GA_send_call(ga::sdk::session& session, const nlohmann::json& tx_details)
    : GA_twofactor_call(session, "send_raw_tx")
    , m_tx_details(tx_details)
    , m_twofactor_required(!m_methods.empty())
    , m_under_limit(false)
    , m_bumping_fee(tx_details.find("previous_transaction") != tx_details.end())
{
    const uint32_t limit = m_twofactor_required ? session.get_spending_limits()["satoshi"].get<uint32_t>() : 0;
    const uint32_t satoshi = m_tx_details["satoshi"];
    const uint32_t fee = m_tx_details["fee"];

    m_limit_details = { { "asset", "BTC" }, { "amount", satoshi + fee }, { "fee", fee },
        { "change_idx", m_tx_details["change_index"] } };

    if (limit != 0 && satoshi + fee <= limit) {
        // 2fa is enabled and we have a spending limit, but this tx is under it.
        m_under_limit = true;
        m_state = state_type::make_call;
    }

    if (m_state == state_type::make_call) {
        // We are ready to call, so make the required twofactor data
        create_twofactor_data();
    }
}

void GA_send_call::request_code(const std::string& method)
{
    // If we are requesting a code, either:
    // 1) Caller has 2FA configured and the tx is not under limits, OR
    // 2) Tx was thought to be under limits but limits have now changed
    // Prevent the call from trying to send using the limit next time through the state machine
    m_under_limit = false;
    create_twofactor_data();
    GA_twofactor_call::request_code(method);
}

void GA_send_call::create_twofactor_data()
{
    m_twofactor_data = nlohmann::json();
    if (m_twofactor_required) {
        if (m_bumping_fee) {
            m_action = "bump_fee";

            const auto previous_fee = m_tx_details["previous_transaction"].at("fee").get<int>();
            const auto new_fee = m_limit_details.at("fee").get<int>();
            const auto bump_amount = new_fee - previous_fee;
            const auto amount_key = m_under_limit ? "try_under_limits_bump" : "amount";
            m_twofactor_data[amount_key] = bump_amount;
        } else {
            if (m_under_limit) {
                // Tx is under the limit and a send hasn't previously failed causing
                // the user to enter a code. Try sending without 2fa as an under limits spend
                m_twofactor_data["try_under_limits_spend"] = m_limit_details;
            } else {
                // 2FA is provided or not configured. Add the send details
                m_twofactor_data["amount"] = m_limit_details["amount"];
                m_twofactor_data["fee"] = m_limit_details["fee"];
                m_twofactor_data["change_idx"] = m_limit_details["change_idx"];
                // FIXME: recipient
            }
        }
    }
}

GA_twofactor_call::state_type GA_send_call::call_impl()
{
    // The api requires the request and action data to differ, which is non-optimal
    ga::sdk::json_rename_key(m_twofactor_data, "fee", "send_raw_tx_fee");
    ga::sdk::json_rename_key(m_twofactor_data, "change_idx", "send_raw_tx_change_idx");

    const char* amount_key = m_bumping_fee ? "bump_fee_amount" : "send_raw_tx_amount";
    ga::sdk::json_rename_key(m_twofactor_data, "amount", amount_key);

    // FIXME: recipient
    m_result = m_session.send_transaction(m_tx_details, m_twofactor_data);
    return state_type::done;
}

//
// Request 2fa reset
//
GA_twofactor_reset_call::GA_twofactor_reset_call(ga::sdk::session& session, const std::string& email, bool is_dispute)
    : GA_twofactor_call(session, "request_reset")
    , m_reset_email(email)
    , m_is_dispute(is_dispute)
    , m_confirming(false)
{
    m_state = state_type::make_call;
}

GA_twofactor_call::state_type GA_twofactor_reset_call::call_impl()
{
    if (!m_confirming) {
        // Request the reset
        m_result = m_session.reset_twofactor(m_reset_email);
        // Move on to confirming the reset email address
        m_confirming = true;
        m_methods = { { "email" } };
        m_method = "email";
        return state_type::resolve_code;
    } else {
        // Confirm the reset
        m_result = m_session.confirm_twofactor_reset(m_reset_email, m_is_dispute, m_twofactor_data);
        return state_type::done;
    }
}

//
// Cancel 2fa reset
//
GA_twofactor_cancel_reset_call::GA_twofactor_cancel_reset_call(ga::sdk::session& session)
    : GA_twofactor_call(session, "cancel_reset")
{
}

GA_twofactor_call::state_type GA_twofactor_cancel_reset_call::call_impl()
{
    m_result = m_session.cancel_twofactor_reset(m_twofactor_data);
    return state_type::done;
}
