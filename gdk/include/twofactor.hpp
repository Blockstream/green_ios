#ifndef GA_SDK_TWOFACTOR_HPP
#define GA_SDK_TWOFACTOR_HPP
#pragma once

#include "containers.hpp"
#include "session.hpp"

struct GA_twofactor_call {
public:
    explicit GA_twofactor_call(ga::sdk::session& session);
    GA_twofactor_call(ga::sdk::session& session, std::vector<std::string> twofactor_methods);
    GA_twofactor_call(const GA_twofactor_call&) = delete;
    GA_twofactor_call& operator=(const GA_twofactor_call&) = delete;
    GA_twofactor_call(GA_twofactor_call&&) = delete;
    GA_twofactor_call& operator=(GA_twofactor_call&&) = delete;
    virtual ~GA_twofactor_call() = default;

    std::vector<std::string> get_all_twofactor_methods() const;

    nlohmann::json get_twofactor_data() const;

    const std::vector<std::string>& get_twofactor_methods() const;

    void request_code_(const std::string& method, const std::string& action, const nlohmann::json& twofactor_data);

    void resolve_code(const std::string& code);

    virtual void request_code(const std::string& method);

    virtual GA_twofactor_call* get_next_call() { return nullptr; }

    virtual void operator()() = 0;
    virtual nlohmann::json get_result() const;

protected:
    ga::sdk::session& m_session;

    // List of factors available for the call
    // This will be taken from the user settings, if empty no 2fa required
    std::vector<std::string> m_twofactor_methods = get_all_twofactor_methods();

    // Selected 2fa method - generally the user is prompted to select the
    // method from twofactor_methods
    std::string m_twofactor_method_selected;

    // The 2fa code - from the user
    std::string m_twofactor_code;
};

struct GA_twofactor_call_with_next : public GA_twofactor_call {
    using next_ptr = std::unique_ptr<GA_twofactor_call>;

    explicit GA_twofactor_call_with_next(ga::sdk::session& session, next_ptr&& next = next_ptr());

    GA_twofactor_call* get_next_call() override;

protected:
    next_ptr m_next;
};

struct GA_activate_email_call : public GA_twofactor_call {
    explicit GA_activate_email_call(ga::sdk::session& session);
    void operator()() override;
};

struct GA_set_email_call : public GA_twofactor_call_with_next {
    GA_set_email_call(ga::sdk::session& session, std::string email);
    void request_code(const std::string& method) override;
    void operator()() override;

private:
    std::string m_email;
};

struct GA_enable_twofactor : public GA_twofactor_call {
    GA_enable_twofactor(ga::sdk::session& session, const std::string& method);
    void operator()() override;

private:
    std::string m_factor;
};

struct GA_init_enable_twofactor : public GA_twofactor_call_with_next {
    GA_init_enable_twofactor(ga::sdk::session& session, const std::string& method, std::string data);
    void request_code(const std::string& method) override;
    void operator()() override;

private:
    std::string m_factor;
    std::string m_data;
};

struct GA_enable_gauth_call : public GA_twofactor_call {
    GA_enable_gauth_call(ga::sdk::session& session, nlohmann::json twofactor_data);
    void operator()() override;

private:
    nlohmann::json m_twofactor_data;
};

struct GA_init_enable_gauth_call : public GA_twofactor_call_with_next {
    explicit GA_init_enable_gauth_call(ga::sdk::session& session);
    void request_code(const std::string& method) override;
    void operator()() override;
};

struct GA_disable_twofactor : public GA_twofactor_call {
    GA_disable_twofactor(ga::sdk::session& session, std::string method);
    void request_code(const std::string& method) override;
    void operator()() override;

private:
    std::string m_factor;
};

// A call that may require 2fa depending on the arguments/wallet state
//
// Implements a pattern which is:
//   try the api call without 2fa
//   if call fails with 2fa required, try again with 2fa
struct GA_attempt_twofactor_call : public GA_twofactor_call {
    explicit GA_attempt_twofactor_call(ga::sdk::session& session);
    GA_twofactor_call* get_next_call() override;
    void operator()() override;
    virtual void call() = 0;

private:
    bool m_retry = false;
};

#endif
