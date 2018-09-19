#include "include/twofactor.hpp"
#include "include/autobahn_wrapper.hpp"

namespace {
#if 0
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
#endif

struct GA_activate_email_call : public GA_twofactor_call {
    explicit GA_activate_email_call(ga::sdk::session& session)
        : GA_twofactor_call(session, { { "email" } })
    {
    }

    void operator()() override { m_session.activate_email(m_code); }
};

struct GA_set_email_call : public GA_twofactor_call {
    GA_set_email_call(ga::sdk::session& session, std::string email)
        // FIXME: GA_twofactor_call_with_next(session, std::make_unique<GA_activate_email_call>(session))
        : GA_twofactor_call(session)
        , m_email(std::move(email))
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, "set_email", { { "address", m_email } });
    }

    void operator()() override
    {
        const auto twofactor_data = get_twofactor_data();
        m_session.set_email(m_email, twofactor_data);
    }

private:
    std::string m_email;
};

struct GA_enable_twofactor : public GA_twofactor_call {
    GA_enable_twofactor(ga::sdk::session& session, const std::string& method)
        : GA_twofactor_call(session, { { method } })
        , m_factor(method)
    {
    }

    void operator()() override { m_session.enable_twofactor(m_factor, m_code); }

private:
    std::string m_factor;
};

struct GA_init_enable_twofactor : public GA_twofactor_call {
    GA_init_enable_twofactor(ga::sdk::session& session, const std::string& method, std::string data)
        // FIXME: GA_twofactor_call_with_next(session, std::make_unique<GA_enable_twofactor>(session, method))
        : GA_twofactor_call(session)
        , m_factor(method)
        , m_data(std::move(data))
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, "enable_2fa", { { "method", m_factor } });
    }

    void operator()() override
    {
        const auto twofactor_data = get_twofactor_data();
        m_session.init_enable_twofactor(m_factor, m_data, twofactor_data);
    }

private:
    std::string m_factor;
    std::string m_data;
};

struct GA_enable_gauth_call : public GA_twofactor_call {
    GA_enable_gauth_call(ga::sdk::session& session, nlohmann::json twofactor_data)
        : GA_twofactor_call(session, { { "gauth" } })
        , m_twofactor_data(std::move(twofactor_data))
    {
    }

    void operator()() override { m_session.enable_gauth(m_code, m_twofactor_data); }

private:
    nlohmann::json m_twofactor_data;
};

struct GA_init_enable_gauth_call : public GA_twofactor_call {
    GA_init_enable_gauth_call(ga::sdk::session& session)
        : GA_twofactor_call(session)
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, "enable_2fa", { { "method", "gauth" } });
    }

    void operator()() override
    {
        // There is no init_enable_gauth method in the api, the twofactor data is passed
        // directly to enable_gauth. By setting next to GA_enable_gauth_call and forwarding
        // the 2fa data here this difference is hidden from the client.
        const auto twofactor_data = get_twofactor_data();
        // m_next.reset(new GA_enable_gauth_call(m_session, twofactor_data));
    }
};

struct GA_disable_twofactor : public GA_twofactor_call {
    GA_disable_twofactor(ga::sdk::session& session, std::string method)
        : GA_twofactor_call(session)
        , m_factor(std::move(method))
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, "disable_2fa", { { "method", m_factor } });
    }

    void operator()() override
    {
        const auto twofactor_data = get_twofactor_data();
        m_session.disable_twofactor(m_factor, twofactor_data);
    }

private:
    std::string m_factor;
};

} // namespace

GA_twofactor_call::GA_twofactor_call(ga::sdk::session& session)
    : m_session(session)
    , m_methods(session.get_all_twofactor_methods())
{
}

GA_twofactor_call::GA_twofactor_call(ga::sdk::session& session, std::vector<std::string> twofactor_methods)
    : m_session(session)
    , m_methods(std::move(twofactor_methods))
    , m_state(m_methods.empty() ? state_type::make_call : state_type::request_code)
{
}

nlohmann::json GA_twofactor_call::get_twofactor_data() const
{
    if (!m_method.empty()) {
        // If this assert fires check that the call has been resolved
        // by calling GA_twofactor_resolve_code
        GA_SDK_RUNTIME_ASSERT(!m_code.empty());

        return { { "method", m_method }, { "code", m_code } };
    }

    return nlohmann::json();
}

void GA_twofactor_call::request_code_impl(
    const std::string& method, const std::string& action, const nlohmann::json& twofactor_data)
{
    // For gauth request code is a no-op
    if (method != "gauth") {
        m_session.twofactor_request_code(method, action, twofactor_data);
    }

    m_method = method;
}

void GA_twofactor_call::request_code(const std::string& method) { m_method = method; }

void GA_twofactor_call::resolve_code(const std::string& code)
{
    GA_SDK_RUNTIME_ASSERT(!m_method.empty());
    m_code = code;
    m_methods.clear();
}

nlohmann::json GA_twofactor_call::get_status() const
{
    // FIXME
    return nlohmann::json();
}

#if 0
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
            m_methods = get_all_twofactor_methods();
            m_retry = true;
        } else {
            throw;
        }
    }
}
#endif
