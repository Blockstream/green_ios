#ifndef GA_SDK_TWOFACTOR_CALLS_HPP
#define GA_SDK_TWOFACTOR_CALLS_HPP
#pragma once

#include "include/twofactor.hpp"

struct GA_send_call : public GA_twofactor_call {
    explicit GA_send_call(ga::sdk::session& session, const nlohmann::json &tx_details)
        : GA_twofactor_call(session, "send_raw_tx")
          , m_tx_details(tx_details)
    {
        // FIXME: use tx_details to check if we need 2fa up front
    }

    void request_code(const std::string& method) override
    {
        // FIXME: use tx details to populate under limit data
        request_code_impl(method, { });
    }

    void call_impl() override {
        m_result = m_session.send(m_tx_details, get_twofactor_data());
    }

    nlohmann::json m_tx_details;
};

#endif
