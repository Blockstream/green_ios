#ifndef GA_SDK_GA_TX_HPP
#define GA_SDK_GA_TX_HPP
#pragma once

#include "containers.hpp"
#include "include/session.hpp"
#include "network_parameters.hpp"

namespace ga {
namespace sdk {

    nlohmann::json create_ga_transaction(
        session& session, const network_parameters& net_params, const nlohmann::json& details);

    nlohmann::json sign_ga_transaction(session& session, const nlohmann::json& details);

    nlohmann::json send_ga_transaction(
        session& session, const nlohmann::json& details, const nlohmann::json& twofactor_data);

} // namespace sdk
} // namespace ga

#endif
