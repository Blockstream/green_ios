#ifndef GA_SDK_TWOFACTOR_HPP
#define GA_SDK_TWOFACTOR_HPP
#pragma once

#include "containers.hpp"
#include "session.hpp"

struct GA_twofactor_call {
public:
    explicit GA_twofactor_call(ga::sdk::session& session, const std::string& action);
    GA_twofactor_call(ga::sdk::session& session, const std::string& action, std::vector<std::string> twofactor_methods);
    GA_twofactor_call(const GA_twofactor_call&) = delete;
    GA_twofactor_call& operator=(const GA_twofactor_call&) = delete;
    GA_twofactor_call(GA_twofactor_call&&) = delete;
    GA_twofactor_call& operator=(GA_twofactor_call&&) = delete;
    virtual ~GA_twofactor_call() = default;

    virtual void request_code(const std::string& method) = 0;
    void resolve_code(const std::string& code);

    virtual nlohmann::json get_status() const;
    virtual void operator()();

protected:
    nlohmann::json get_twofactor_data() const;

    void request_code_impl(const std::string& method, const nlohmann::json& twofactor_data);
    virtual void call_impl() = 0;

    enum class state_type : uint32_t {
        request_code, // Caller should ask the user to pick 2fa and request a code
        resolve_code, // Caller should resolve the code the user has entered
        make_call, // Caller should make the call
        done, // Caller should destroy the call and continue
        error // User should handle the error
    };

    ga::sdk::session& m_session;
    std::vector<std::string> m_methods; // Al available methods
    std::string m_method; // Selected 2fa method
    std::string m_action; // Selected 2fa action name (send_raw_tx, set_csvtime etc)
    std::string m_code; // The 2fa code - from the user
    nlohmann::json m_error; // Error details if any
    nlohmann::json m_result; // Result of any successful action
    state_type m_state; // Current state
};

#endif
