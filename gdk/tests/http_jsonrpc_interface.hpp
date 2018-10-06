#ifndef GA_SDK_HTTP_JSONRPC_INTERFACE_HPP
#define GA_SDK_HTTP_JSONRPC_INTERFACE_HPP
#pragma once

#include <string>
#include <vector>

namespace ga {
namespace sdk {

    struct http_jsonrpc_client {

        std::string make_sendtoaddress_request(const std::string& address, double amount);

        std::string make_sendmany_request(const std::vector<std::pair<std::string, double>>& address_amounts);

        std::string make_generate_request(uint32_t num_blocks);

        std::string sync_post(const std::string& host, const std::string& port, const std::string& request);
    };
} // namespace sdk
} // namespace ga

#endif
