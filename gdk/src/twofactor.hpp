#ifndef GA_SDK_TWOFACTOR_HPP
#define GA_SDK_TWOFACTOR_HPP
#pragma once

#include "containers.hpp"
#include "session.hpp"

struct GA_twofactor_factor final {
public:
    GA_twofactor_factor(std::string type)
        : m_type(std::move(type))
    {
    }

    const std::string& get_type() const { return m_type; }

private:
    std::string m_type;
};

struct GA_twofactor_factor_list {
public:
    using value_container = std::vector<GA_twofactor_factor>;
    using size_type = value_container::size_type;

    explicit GA_twofactor_factor_list(value_container list)
        : m_list(std::move(list))
    {
    }

    GA_twofactor_factor operator[](size_t i) const { return GA_twofactor_factor(m_list[i]); }

    size_type size() const { return m_list.size(); }

private:
    value_container m_list;
};

struct GA_twofactor_call {
public:
    explicit GA_twofactor_call(ga::sdk::session& session);
    GA_twofactor_call(ga::sdk::session& session, std::vector<GA_twofactor_factor> twofactor_factors);
    GA_twofactor_call(const GA_twofactor_call&) = delete;
    GA_twofactor_call& operator=(const GA_twofactor_call&) = delete;
    GA_twofactor_call(GA_twofactor_call&&) = delete;
    GA_twofactor_call& operator=(GA_twofactor_call&&) = delete;
    virtual ~GA_twofactor_call() = default;

    std::vector<GA_twofactor_factor> get_all_twofactor_factors() const;

    nlohmann::json get_twofactor_data() const;

    const std::vector<GA_twofactor_factor>& get_twofactor_factors() const;

    void request_code_(
        const GA_twofactor_factor& factor, const std::string& action, const nlohmann::json& twofactor_data);

    void resolve_code(const std::string& code);

    virtual void request_code(const GA_twofactor_factor& factor);

    virtual GA_twofactor_call* get_next_call() { return nullptr; }

    virtual void operator()() = 0;

protected:
    ga::sdk::session& m_session;

    // List of factors available for the call
    // This will be taken from the user settings, if empty no 2fa required
    std::vector<GA_twofactor_factor> m_twofactor_factors = get_all_twofactor_factors();

    // Selected 2fa factor - generally the user is prompted to select the
    // factor from twofactor_factors
    const GA_twofactor_factor* m_twofactor_factor_selected = nullptr;

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
    void request_code(const GA_twofactor_factor& factor) override;
    void operator()() override;

private:
    std::string m_email;
};

struct GA_enable_twofactor : public GA_twofactor_call {
    GA_enable_twofactor(ga::sdk::session& session, const std::string& factor);
    void operator()() override;

private:
    std::string m_factor;
};

struct GA_init_enable_twofactor : public GA_twofactor_call_with_next {
    GA_init_enable_twofactor(ga::sdk::session& session, const std::string& factor, std::string data);
    void request_code(const GA_twofactor_factor& factor) override;
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
    void request_code(const GA_twofactor_factor& factor) override;
    void operator()() override;
};

struct GA_disable_twofactor : public GA_twofactor_call {
    GA_disable_twofactor(ga::sdk::session& session, std::string factor);
    void request_code(const GA_twofactor_factor& factor) override;
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

struct GA_change_tx_limits_call : public GA_attempt_twofactor_call {
    GA_change_tx_limits_call(ga::sdk::session& session, std::string total);
    void request_code(const GA_twofactor_factor& factor) override;
    void call() override;

private:
    std::string m_total;
};

struct GA_send_call : public GA_attempt_twofactor_call {
    using outputs_t = std::vector<ga::sdk::session::address_amount_pair>;
    using fee_rate_t = ga::sdk::amount;

    GA_send_call(ga::sdk::session& session, outputs_t addr_amount, const fee_rate_t& fee_rate, bool send_all);

    void request_code(const GA_twofactor_factor& factor) override;
    void call() override;

private:
    outputs_t m_outputs;
    fee_rate_t m_fee_rate;
    bool m_send_all;
};

#endif
