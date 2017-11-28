#ifndef GA_SDK_HTTP_JSONRPC_INTERFACE_HPP
#define GA_SDK_HTTP_JSONRPC_INTERFACE_HPP
#pragma once

#include <string>

namespace ga {
namespace sdk {

    struct http_jsonrpc_client {
        std::string make_send_to_address(const std::string& address, const std::string& amount);
        std::string sync_post(const std::string& host, const std::string& port, const std::string& request);
    };
}
}

#endif
