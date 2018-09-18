#include "include/twofactor.hpp"
#include "include/autobahn_wrapper.hpp"

namespace {
// Return true if the error represents 'two factor authentication required'
bool is_twofactor_required_error(const autobahn::call_error& e)
{
    const autobahn::call_error::args_type& args = e.get_args();
    if (!args.empty()) {
        std::string uri;
        args[0].convert(uri);
        if (uri == "http://greenaddressit.com/error#auth") {
            return true;
        }
    }
    return false;
}
} // namespace

std::vector<std::string> GA_twofactor_call::get_all_twofactor_methods() const
{
    const auto twofactor_config = m_session.get_twofactor_config();
    std::vector<std::string> methods;
    for (auto method : { "email", "sms", "phone", "gauth" }) {
        const bool enabled = twofactor_config[method];
        if (enabled) {
            methods.emplace_back(method);
        }
    }
    return methods;
}

const std::vector<std::string>& GA_twofactor_call::get_twofactor_methods() const { return m_twofactor_methods; }

GA_twofactor_call::GA_twofactor_call(ga::sdk::session& session)
    : m_session(session)
    , m_twofactor_methods(get_all_twofactor_methods())
{
}

GA_twofactor_call::GA_twofactor_call(ga::sdk::session& session, std::vector<std::string> twofactor_methods)
    : m_session(session)
    , m_twofactor_methods(std::move(twofactor_methods))
{
}

nlohmann::json GA_twofactor_call::get_twofactor_data() const
{
    if (!m_twofactor_method_selected.empty()) {
        // If this assert fires check that the call has been resolved
        // by calling GA_twofactor_resolve_code
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_code.empty());

        return { { "method", m_twofactor_method_selected }, { "code", m_twofactor_code } };
    }

    return nlohmann::json();
}

void GA_twofactor_call::request_code_(
    const std::string& method, const std::string& action, const nlohmann::json& twofactor_data)
{
    // For gauth request code is a no-op
    if (method != "gauth") {
        m_session.twofactor_request_code(method, action, twofactor_data);
    }

    m_twofactor_method_selected = method;
}

void GA_twofactor_call::request_code(const std::string& method) { m_twofactor_method_selected = method; }

void GA_twofactor_call::resolve_code(const std::string& code)
{
    GA_SDK_RUNTIME_ASSERT(!m_twofactor_method_selected.empty());
    m_twofactor_code = code;
    m_twofactor_methods.clear();
}

nlohmann::json GA_twofactor_call::get_result() const { return nlohmann::json(); }

GA_twofactor_call_with_next::GA_twofactor_call_with_next(ga::sdk::session& session, next_ptr&& next)
    : GA_twofactor_call(session)
    , m_next(std::move(next))
{
}

struct GA_twofactor_call* GA_twofactor_call_with_next::get_next_call() { return m_next.get(); }

GA_activate_email_call::GA_activate_email_call(ga::sdk::session& session)
    : GA_twofactor_call(session, { { "email" } })
{
}

void GA_activate_email_call::operator()() { m_session.activate_email(m_twofactor_code); }

GA_set_email_call::GA_set_email_call(ga::sdk::session& session, std::string email)
    : GA_twofactor_call_with_next(session, std::make_unique<GA_activate_email_call>(session))
    , m_email(std::move(email))
{
}

void GA_set_email_call::request_code(const std::string& method)
{
    request_code_(method, "set_email", { { "address", m_email } });
}

void GA_set_email_call::operator()()
{
    const auto twofactor_data = get_twofactor_data();
    m_session.set_email(m_email, twofactor_data);
}

// enable...

GA_enable_twofactor::GA_enable_twofactor(ga::sdk::session& session, const std::string& method)
    : GA_twofactor_call(session, { { method } })
    , m_factor(method)
{
}

void GA_enable_twofactor::operator()() { m_session.enable_twofactor(m_factor, m_twofactor_code); }

// gauth is different
GA_enable_gauth_call::GA_enable_gauth_call(ga::sdk::session& session, nlohmann::json twofactor_data)
    : GA_twofactor_call(session, { { "gauth" } })
    , m_twofactor_data(std::move(twofactor_data))
{
}

void GA_enable_gauth_call::operator()() { m_session.enable_gauth(m_twofactor_code, m_twofactor_data); }

// init_enable

GA_init_enable_twofactor::GA_init_enable_twofactor(
    ga::sdk::session& session, const std::string& method, std::string data)
    : GA_twofactor_call_with_next(session, std::make_unique<GA_enable_twofactor>(session, method))
    , m_factor(method)
    , m_data(std::move(data))
{
}

void GA_init_enable_twofactor::request_code(const std::string& method)
{
    request_code_(method, "enable_2fa", { { "method", m_factor } });
}

void GA_init_enable_twofactor::operator()()
{
    const auto twofactor_data = get_twofactor_data();
    m_session.init_enable_twofactor(m_factor, m_data, twofactor_data);
}

GA_init_enable_gauth_call::GA_init_enable_gauth_call(ga::sdk::session& session)
    : GA_twofactor_call_with_next(session)
{
}

void GA_init_enable_gauth_call::request_code(const std::string& method)
{
    request_code_(method, "enable_2fa", { { "method", "gauth" } });
}

void GA_init_enable_gauth_call::operator()()
{
    // There is no init_enable_gauth method in the api, the twofactor data is passed
    // directly to enable_gauth. By setting next to GA_enable_gauth_call and forwarding
    // the 2fa data here this difference is hidden from the client.
    const auto twofactor_data = get_twofactor_data();
    m_next.reset(new GA_enable_gauth_call(m_session, twofactor_data));
}

// disable

GA_disable_twofactor::GA_disable_twofactor(ga::sdk::session& session, std::string method)
    : GA_twofactor_call(session)
    , m_factor(std::move(method))
{
}

void GA_disable_twofactor::request_code(const std::string& method)
{
    request_code_(method, "disable_2fa", { { "method", m_factor } });
}

void GA_disable_twofactor::operator()()
{
    const auto twofactor_data = get_twofactor_data();
    m_session.disable_twofactor(m_factor, twofactor_data);
}

GA_attempt_twofactor_call::GA_attempt_twofactor_call(ga::sdk::session& session)
    : GA_twofactor_call(session, {}) // start as a vanilla call with no 2fa
{
}

struct GA_twofactor_call* GA_attempt_twofactor_call::get_next_call() { return m_retry ? this : nullptr; }

void GA_attempt_twofactor_call::operator()()
{
    try {
        call();
        m_retry = false;
    } catch (const autobahn::call_error& e) {
        if (is_twofactor_required_error(e) && !m_retry) {
            // Enable 2fa and try again
            m_twofactor_methods = get_all_twofactor_methods();
            m_retry = true;
        } else {
            throw;
        }
    }
}
