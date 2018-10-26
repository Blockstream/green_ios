#include <iostream>
#include <nlohmann/json.hpp>

#include "http_jsonrpc_interface.hpp"
#include "src/assertion.hpp"
#include "src/boost_wrapper.hpp"

namespace ga {
namespace sdk {
    namespace {
        static nlohmann::json get_rpc_request(const std::string& name)
        {
            return { { "jsonrpc", "1.0" }, { "id", name }, { "method", name } };
        }

    } // namespace

    std::string http_jsonrpc_client::make_sendtoaddress_request(const std::string& address, double amount)
    {
        return make_sendmany_request(std::vector<std::pair<std::string, double>>{ std::make_pair(address, amount) });
    }

    std::string http_jsonrpc_client::make_sendmany_request(
        const std::vector<std::pair<std::string, double>>& address_amounts)
    {
        nlohmann::json request = get_rpc_request("sendmany");
        auto& params = request["params"];
        params = std::vector<std::string>{ std::string() }; // Account
        nlohmann::json addressees;
        for (const auto& aa : address_amounts) {
            addressees[aa.first] = aa.second;
        }
        params.emplace_back(addressees);
        return request.dump();
    }

    std::string http_jsonrpc_client::make_generate_request(uint32_t num_blocks)
    {
        nlohmann::json request = get_rpc_request("generate");
        request["params"] = std::vector<uint32_t>{ num_blocks };
        return request.dump();
    }

    std::string http_jsonrpc_client::sync_post(
        const std::string& host, const std::string& port, const std::string& request)
    {
        namespace asio = boost::asio;
        using boost::asio::ip::tcp;

        asio::io_service io;

        tcp::resolver resolver{ io };
        tcp::resolver::query query{ tcp::v4(), host, port };
        const auto endpoint_iterator = resolver.resolve(query);

        tcp::socket socket{ io };
        asio::connect(socket, endpoint_iterator);

        asio::streambuf request_buffer;
        std::ostream request_stream(&request_buffer);
        request_stream << "POST / HTTP/1.1\r\n";
        request_stream << "Host: " << host << ":" << port << "\r\n";
        request_stream << "Authorization: Basic YWRtaW4xOjEyMw==\r\n";
        request_stream << "User-Agent: GA SDK\r\n";
        request_stream << "Accept: */*\r\n";
        request_stream << "Content-Type: application/json-rpc\r\n";
        request_stream << "Content-Length: " << request.length() << "\r\n\r\n";
        request_stream << request;

        boost::system::error_code ec;
        asio::write(socket, request_buffer, ec);
        GA_SDK_RUNTIME_ASSERT(!ec);

        asio::streambuf response_buffer;
        asio::read(socket, response_buffer, asio::transfer_all(), ec);
        GA_SDK_RUNTIME_ASSERT(ec == asio::error::eof);

        return std::string(std::istreambuf_iterator<char>(&response_buffer), std::istreambuf_iterator<char>());
    }
} // namespace sdk
} // namespace ga
