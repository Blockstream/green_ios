#include <iostream>

#include "src/boost_wrapper.hpp"

#include "http_jsonrpc_interface.hpp"
#include "src/assertion.hpp"

namespace ga {
namespace sdk {

    std::string http_jsonrpc_client::make_send_to_address(const std::string& address, const std::string& amount)
    {
        std::ostringstream strm;
        strm << R"rawlit({"jsonrpc": "1.0", "id":"sendtoaddress", "method": "sendtoaddress", "params": [)rawlit";
        strm << "\"" << address << "\"";
        strm << ",";
        strm << amount;
        strm << "]}";

        return strm.str();
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
