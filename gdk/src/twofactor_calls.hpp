#ifndef GA_SDK_TWOFACTOR_CALLS_HPP
#define GA_SDK_TWOFACTOR_CALLS_HPP
#pragma once

#include "include/twofactor.hpp"

class GA_register_call : public GA_twofactor_call {
public:
    GA_register_call(
        ga::sdk::session& session, const nlohmann::json& hw_details, const std::string& user_agent = std::string());

private:
    state_type call_impl() override;

    std::string m_user_agent;
};

class GA_login_call : public GA_twofactor_call {
public:
    GA_login_call(
        ga::sdk::session& session, const nlohmann::json& hw_details, const std::string& user_agent = std::string());

private:
    void set_data(const std::string& action);

    state_type call_impl() override;

    std::string m_user_agent;
    std::string m_challenge;
};

class GA_sign_transaction_call : public GA_twofactor_call {
public:
    GA_sign_transaction_call(
        ga::sdk::session& session, const nlohmann::json& hw_details, const nlohmann::json& tx_details);

private:
    state_type call_impl() override;

    nlohmann::json m_tx_details;
};

class GA_change_settings_twofactor_call : public GA_twofactor_call {
public:
    GA_change_settings_twofactor_call(
        ga::sdk::session& session, const std::string& method_to_update, const nlohmann::json& details);

private:
    state_type call_impl() override;

    state_type on_init_done(const std::string& new_action);

    nlohmann::json m_current_config;
    std::string m_method_to_update;
    nlohmann::json m_details;
    nlohmann::json m_gauth_data;
    bool m_enabling;
};

class GA_change_limits_call : public GA_twofactor_call {
public:
    GA_change_limits_call(ga::sdk::session& session, const nlohmann::json& details);

    void request_code(const std::string& method) override;

private:
    state_type call_impl() override;

    nlohmann::json m_limit_details;
    bool m_is_decrease;
};

class GA_remove_account_call : public GA_twofactor_call {
public:
    GA_remove_account_call(ga::sdk::session& session);

private:
    state_type call_impl() override;
};

class GA_send_call final : public GA_twofactor_call {
public:
    GA_send_call(ga::sdk::session& session, const nlohmann::json& tx_details);

    void request_code(const std::string& method) override;

private:
    state_type call_impl() override;

    void create_twofactor_data();

    nlohmann::json m_tx_details;
    nlohmann::json m_limit_details;
    bool m_twofactor_required;
    bool m_under_limit;
    bool m_bumping_fee;
};

class GA_twofactor_reset_call : public GA_twofactor_call {
public:
    GA_twofactor_reset_call(ga::sdk::session& session, const std::string& email, bool is_dispute);

private:
    state_type call_impl() override;

    std::string m_reset_email;
    bool m_is_dispute;
    bool m_confirming;
};

class GA_twofactor_cancel_reset_call final : public GA_twofactor_call {
public:
    GA_twofactor_cancel_reset_call(ga::sdk::session& session);

private:
    state_type call_impl() override;
};

#endif
