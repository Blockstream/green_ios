#ifndef GA_SDK_TWOFACTOR_CALLS_HPP
#define GA_SDK_TWOFACTOR_CALLS_HPP
#pragma once

#include "include/twofactor.hpp"

class GA_change_settings_twofactor_call : public GA_twofactor_call {
public:
    GA_change_settings_twofactor_call(
        ga::sdk::session& session, const std::string& method_to_update, const nlohmann::json& details);

    void request_code(const std::string& method_to_update) override;

private:
    state_type call_impl() override;

    state_type on_init_done(const std::string& new_action);

    nlohmann::json m_current_config;
    std::string m_method_to_update;
    nlohmann::json m_details;
    nlohmann::json m_init_twofactor_data;
    bool m_enabling;
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
};

#endif
