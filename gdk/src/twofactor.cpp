#include "twofactor.hpp"
#include "autobahn_wrapper.hpp"

namespace {
// Return true if the error represents 'two factor authentication required'
bool is_twofactor_required_error(const autobahn::call_error& e)
{
    const autobahn::call_error::args_type& args = e.get_args();
    if (args.size() > 0) {
        std::string uri;
        args[0].convert(uri);
        if (uri == "http://greenaddressit.com/error#auth") {
            return true;
        }
    }
    return false;
}
} // namespace

GA_twofactor_factor::GA_twofactor_factor(const std::string& type)
    : m_type(type)
{
}

std::vector<GA_twofactor_factor> GA_twofactor_call::get_all_twofactor_factors() const
{
    const auto twofactor_config = m_session.get_twofactor_config();
    std::vector<GA_twofactor_factor> methods;
    for (auto factor : { "email", "sms", "phone", "gauth" }) {
        const bool enabled = twofactor_config[factor];
        if (enabled) {
            methods.emplace_back(GA_twofactor_factor(factor));
        }
    }
    return methods;
}

const std::vector<GA_twofactor_factor>& GA_twofactor_call::get_twofactor_factors() const { return m_twofactor_factors; }

GA_twofactor_call::GA_twofactor_call(ga::sdk::session& session)
    : m_session(session)
    , m_twofactor_factors(get_all_twofactor_factors())
{
}

GA_twofactor_call::GA_twofactor_call(
    ga::sdk::session& session, const std::vector<GA_twofactor_factor>& twofactor_factors_)
    : m_session(session)
    , m_twofactor_factors(twofactor_factors_)
{
}

nlohmann::json GA_twofactor_call::get_twofactor_data() const
{
    if (m_twofactor_factor_selected) {
        // If this assert fires check that the call has been resolved
        // by calling GA_twofactor_resolve_code
        GA_SDK_RUNTIME_ASSERT(!m_twofactor_code.empty());
        GA_SDK_RUNTIME_ASSERT(m_twofactor_factor_selected != nullptr);

        return { { "method", m_twofactor_factor_selected->get_type() }, { "code", m_twofactor_code } };
    }

    return nlohmann::json();
}

void GA_twofactor_call::request_code_(
    const GA_twofactor_factor& factor, const std::string& action, const nlohmann::json& twofactor_data)
{
    // For gauth request code is a no-op
    if (factor.get_type() != "gauth") {
        m_session.twofactor_request_code(factor.get_type(), action, twofactor_data);
    }

    m_twofactor_factor_selected = &factor;
}

void GA_twofactor_call::request_code(const GA_twofactor_factor& factor) { m_twofactor_factor_selected = &factor; }

void GA_twofactor_call::resolve_code(const std::string& code)
{
    GA_SDK_RUNTIME_ASSERT(m_twofactor_factor_selected);
    m_twofactor_code = code;
    m_twofactor_factors.clear();
}

GA_twofactor_call::~GA_twofactor_call() {}

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

GA_set_email_call::GA_set_email_call(ga::sdk::session& session, const std::string& email)
    : GA_twofactor_call_with_next(session, next_ptr(new GA_activate_email_call(session)))
    , m_email(email)
{
}

void GA_set_email_call::request_code(const GA_twofactor_factor& factor)
{
    request_code_(factor, "set_email", { { "address", m_email } });
}

void GA_set_email_call::operator()()
{
    const auto twofactor_data = get_twofactor_data();
    m_session.set_email(m_email.c_str(), twofactor_data);
}

// enable...

GA_enable_twofactor::GA_enable_twofactor(ga::sdk::session& session, const std::string& factor)
    : GA_twofactor_call(session, { { factor } })
    , m_factor(factor)
{
}

void GA_enable_twofactor::operator()() { m_session.enable_twofactor(m_factor, m_twofactor_code); }

// gauth is different
GA_enable_gauth_call::GA_enable_gauth_call(ga::sdk::session& session, const nlohmann::json& twofactor_data)
    : GA_twofactor_call(session, { { "gauth" } })
    , m_twofactor_data(twofactor_data)
{
}

void GA_enable_gauth_call::operator()() { m_session.enable_gauth(m_twofactor_code, m_twofactor_data); }

// init_enable

GA_init_enable_twofactor::GA_init_enable_twofactor(
    ga::sdk::session& session, const std::string& factor, const std::string& data)
    : GA_twofactor_call_with_next(session, next_ptr(new GA_enable_twofactor(session, factor)))
    , m_factor(factor)
    , m_data(data)
{
}

void GA_init_enable_twofactor::request_code(const GA_twofactor_factor& factor)
{
    request_code_(factor, "enable_2fa", { { "method", m_factor } });
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

void GA_init_enable_gauth_call::request_code(const GA_twofactor_factor& factor)
{
    request_code_(factor, "enable_2fa", { { "method", "gauth" } });
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

GA_disable_twofactor::GA_disable_twofactor(ga::sdk::session& session, const std::string& factor)
    : GA_twofactor_call(session)
    , m_factor(factor)
{
}

void GA_disable_twofactor::request_code(const GA_twofactor_factor& factor)
{
    request_code_(factor, "disable_2fa", { { "method", m_factor } });
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
            m_twofactor_factors = get_all_twofactor_factors();
            m_retry = true;
        } else {
            throw;
        }
    }
}

GA_change_tx_limits_call::GA_change_tx_limits_call(ga::sdk::session& session, const std::string& total)
    : GA_attempt_twofactor_call(session)
    , m_total(total)
{
}

void GA_change_tx_limits_call::request_code(const GA_twofactor_factor& factor)
{
    // TODO: need to support fiat limits and per_tx
    request_code_(factor, "change_tx_limits", { { "is_fiat", 0 }, { "total", m_total }, { "per_tx", 0 } });
}

void GA_change_tx_limits_call::call()
{
    const auto twofactor_data = get_twofactor_data();
    m_session.change_settings_tx_limits(0, 0, std::stoi(m_total), twofactor_data);
}

GA_send_call::GA_send_call(
    ga::sdk::session& session, const outputs_t& addr_amount, const fee_rate_t& fee_rate, bool send_all)
    : GA_attempt_twofactor_call(session)
    , m_outputs(addr_amount)
    , m_fee_rate(fee_rate)
    , m_send_all(send_all)
{
}

void GA_send_call::request_code(const GA_twofactor_factor& factor) { request_code_(factor, "send_tx", {}); }

void GA_send_call::call()
{
    const auto twofactor_data = get_twofactor_data();
    m_session.send(m_outputs, m_fee_rate, m_send_all, twofactor_data);
}
