#include <iostream>

#include "include/boost_wrapper.hpp"

#include "http_jsonrpc_interface.hpp"
#include "include/assertion.hpp"

namespace ga {
namespace sdk {

    std::string http_jsonrpc_client::make_send_to_address(const std::string& address, const std::string& amount)
    {
        const std::vector<std::pair<std::string, std::string>> addressees = { { std::make_pair(address, amount) } };
        return make_send_to_addressees(addressees);
    }

    std::string http_jsonrpc_client::make_send_to_addressees(
        const std::vector<std::pair<std::string, std::string>>& addressees)
    {
        std::string sep;
        std::ostringstream os;
        os << R"rawlit({"jsonrpc": "1.0", "id":"sendmany", "method": "sendmany", "params": ["", {)rawlit";
        for (const auto& a : addressees) {
            os << sep << '"' << a.first << "\":" << a.second;
            sep = ",";
        }
        os << "}]}";
        return os.str();
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
