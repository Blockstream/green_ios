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

#if 0
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
        : GA_twofactor_call(session, "set_email")
        , m_email(std::move(email))
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, { { "address", m_email } });
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
        : GA_twofactor_call(session, "enable_2fa")
        , m_factor(method)
        , m_data(std::move(data))
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, { { "method", m_factor } });
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
        : GA_twofactor_call(session, "enable_2fa")
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, { { "method", "gauth" } });
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
        : GA_twofactor_call(session, "disable_2fa")
        , m_factor(std::move(method))
    {
    }

    void request_code(const std::string& method) override
    {
        request_code_impl(method, { { "method", m_factor } });
    }

    void operator()() override
    {
        const auto twofactor_data = get_twofactor_data();
        m_session.disable_twofactor(m_factor, twofactor_data);
    }

private:
    std::string m_factor;
};
#endif
} // namespace

GA_twofactor_call::GA_twofactor_call(ga::sdk::session& session, const std::string& action)
    : GA_twofactor_call(session, action, session.get_all_twofactor_methods())
{
}

GA_twofactor_call::GA_twofactor_call(
    ga::sdk::session& session, const std::string& action, std::vector<std::string> twofactor_methods)
    : m_session(session)
    , m_methods(std::move(twofactor_methods))
    , m_action(action)
    , m_state(m_methods.empty() ? state_type::make_call : state_type::request_code)
{
}

void GA_twofactor_call::request_code_impl(const std::string& method, const nlohmann::json& twofactor_data)
{
    GA_SDK_RUNTIME_ASSERT(m_state == state_type::request_code);

    // For gauth request code is a no-op
    if (method != "gauth") {
        m_session.twofactor_request_code(method, m_action, twofactor_data);
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
    try {
        GA_SDK_RUNTIME_ASSERT(m_state == state_type::make_call);
        call_impl();
        m_state = state_type::done;
    } catch (const autobahn::call_error& e) {
        if (is_twofactor_required_error(e)) {
            // Make the user request another code
            // FIXME: If the exception is wrong code and we are within the time limit,
            // move to state resolve_code instead
            // If we are rate limited, move to error and give a message
            m_state = state_type::request_code;
        } else {
            m_state = state_type::error;
        }
    }
}

nlohmann::json GA_twofactor_call::get_status() const
{
    GA_SDK_RUNTIME_ASSERT(m_state == state_type::error || m_error.is_null());

    switch (m_state) {
    case state_type::request_code:
        // Caller should ask the user to pick 2fa and request a code
        return { { "status", "request_code" }, { "methods", m_methods } };
        break;
    case state_type::resolve_code:
        // Caller should resolve the code the user has entered
        return { { "status", "resolve_code" }, { "method", m_method } };
        break;
    case state_type::make_call:
        // Caller should make the call
        return { { "status", "call" } };
        break;
    case state_type::done:
        // Caller should destry the call and continue
        return { { "status", "done" }, { "result", m_result } };
        break;
    case state_type::error:
        // User should handle the error
        return { { "status", "error" }, { "error", m_error } };
        break;
    }
    GA_SDK_RUNTIME_ASSERT(false);
    __builtin_unreachable();
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
