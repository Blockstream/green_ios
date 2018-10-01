#include "include/twofactor.hpp"
#include "include/autobahn_wrapper.hpp"
#include "include/containers.hpp"

namespace {
// Server gives 3 attempts to get the twofactor code right before it's invalidated
const uint32_t TWO_FACTOR_ATTEMPTS = 3;

// Return true if the error represents 'two factor authentication required'
std::string get_twofactor_error_message(const autobahn::call_error& e)
{
    std::string message;
    const auto& args = e.get_args();
    if (args.size() >= 2) {
        std::string uri;
        args[0].convert(uri);
        if (boost::algorithm::ends_with(uri, "#auth")) {
            args[1].convert(message);
        }
    }
    return message;
}
bool is_twofactor_invalid_code_error(const autobahn::call_error& e)
{
    return get_twofactor_error_message(e) == "Invalid Two Factor Authentication Code";
}
} // namespace

GA_twofactor_call::GA_twofactor_call(ga::sdk::session& session, const std::string& action)
    : m_session(session)
    , m_methods(session.get_enabled_twofactor_methods())
    , m_action(action)
    , m_state(m_methods.empty() ? state_type::make_call : state_type::request_code)
    , m_attempts_remaining(TWO_FACTOR_ATTEMPTS)
{
}

void GA_twofactor_call::set_error(const std::string& error_message)
{
    m_state = state_type::error;
    m_error = { { "error", error_message } };
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
            m_state = state_type::error;
        }
    }
}

nlohmann::json GA_twofactor_call::get_status() const
{
    GA_SDK_RUNTIME_ASSERT(m_state == state_type::error || m_error.is_null());

    std::string status_str;
    nlohmann::json status;

    switch (m_state) {
    case state_type::request_code:
        // Caller should ask the user to pick 2fa and request a code
        status_str = "request_code";
        status["methods"] = m_methods;
        break;
    case state_type::resolve_code:
        // Caller should resolve the code the user has entered
        status_str = "resolve_code";
        status["method"] = m_method;
        if (m_method != "gauth") {
            status["attempts_remaining"] = m_attempts_remaining;
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
    return status;
}

// Enable 2FA
GA_change_settings_twofactor_call::GA_change_settings_twofactor_call(
    ga::sdk::session& session, const std::string& method_to_update, const nlohmann::json& details)
    : GA_twofactor_call(session, "init_enable_" + method_to_update)
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
        set_error(m_method + " is already " + (m_enabling ? "enabled" : "disabled"));
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
                set_error("Inconsistent data provided for enabling gauth");
                return;
            }
        }
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

void GA_change_settings_twofactor_call::request_code(const std::string& method) { request_code_impl(method); }

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
    } else if (boost::starts_with(m_action, "init_enable_")) {
        if (m_method_to_update == "gauth") {
            // gauth doesn't have an init_enable step, as its combined into the
            // enable call. So just store any current 2fa data to pass to the
            // enable call along with the gauth code that we will request next
            std::swap(m_init_twofactor_data, m_twofactor_data);
        } else {
            // Otherwise call the init_enable method with the provided data
            const std::string data = ga::sdk::json_get_value(m_details, "data");
            m_session.init_enable_twofactor(m_method_to_update, data, m_twofactor_data);
        }
        // Move to enable the 2fa method
        return on_init_done("enable_");
    } else if (boost::starts_with(m_action, "enable_")) {
        // The user has authorized enabling 2fa (if required), so enable the
        // method using its code (which proves the user got a code from the
        // method being enabled)
        if (m_method_to_update == "gauth") {
            m_session.enable_gauth(m_code, m_init_twofactor_data);
        } else {
            m_session.enable_twofactor(m_method_to_update, m_code);
        }
        return state_type::done;
    } else if (m_action == "disable_2fa") {
        m_session.disable_twofactor(m_method, m_twofactor_data);
        return state_type::done;
    } else {
        GA_SDK_RUNTIME_ASSERT(false);
        __builtin_unreachable();
    }
}

// Remove account
GA_remove_account_call::GA_remove_account_call(ga::sdk::session& session)
    : GA_twofactor_call(session, "remove_account")
{
}

GA_twofactor_call::state_type GA_remove_account_call::call_impl()
{
    m_session.remove_account(m_twofactor_data);
    return state_type::done;
}

// Send transaction
GA_send_call::GA_send_call(ga::sdk::session& session, const nlohmann::json& tx_details)
    : GA_twofactor_call(session, "send_raw_tx")
    , m_tx_details(tx_details)
{
    // FIXME: bumping, bumping under limits
    uint32_t satoshi = m_tx_details["satoshi"];
    uint32_t fee = m_tx_details["fee"];

    m_limit_details = { { "asset", "BTC" }, { "amount", satoshi + fee }, { "fee", m_tx_details["fee"] },
        { "change_idx", m_tx_details["change_index"] } };

    if (!m_tx_details.value("twofactor_required", false)) {
        // No 2FA is required to send this tx
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
    m_tx_details["twofactor_under_limit"] = false;
    m_tx_details["twofactor_required"] = true;

    create_twofactor_data();

    request_code_impl(method);
}

void GA_send_call::create_twofactor_data()
{
    m_twofactor_data = nlohmann::json();
    if (m_tx_details.value("twofactor_required", false)) {
        if (m_tx_details.value("twofactor_under_limit", false)) {
            // Tx is under the limit and a send hasn't previously failed causing
            // the user to enter a code. Try sending without 2fa as an under limits spend
            m_twofactor_data["try_under_limits_spend"] = m_limit_details;
        } else {
            // 2FA is provided or not configured. Add the send details
            m_twofactor_data["send_raw_tx_asset"] = "BTC";
            m_twofactor_data["send_raw_tx_amount"] = m_limit_details["amount"];
            m_twofactor_data["send_raw_tx_fee"] = m_limit_details["fee"];
            m_twofactor_data["send_raw_tx_change_idx"] = m_limit_details["change_idx"];
        }
    }
}

GA_twofactor_call::state_type GA_send_call::call_impl()
{
    m_result = m_session.send(m_tx_details, m_twofactor_data);
    return state_type::done;
}
