
#include <iostream>
#include <memory>
#include <string>
#include <tuple>
#include <unordered_map>

#include <autobahn/autobahn.hpp>
#include <autobahn/wamp_websocketpp_websocket_transport.hpp>

#include <websocketpp/client.hpp>
#include <websocketpp/config/asio_client.hpp>
#include <websocketpp/config/asio_no_tls_client.hpp>

const std::string DEFAULT_REALM("realm1");
const std::string DEFAULT_TLS_ENDPOINT("wss://testwss.greenaddress.it:443/v2/ws");
const std::string DEFAULT_ENDPOINT("ws://localhost:8080/v2/ws");
const std::string DEFAULT_TOPIC("com.greenaddress.blocks");

using tls_client = websocketpp::client<websocketpp::config::asio_tls_client>;
using client = websocketpp::client<websocketpp::config::asio_client>;
using context_ptr = websocketpp::lib::shared_ptr<boost::asio::ssl::context>;

int main(int argc, char** argv)
{
    try {
        boost::asio::io_service io;
        const bool debug = false;

#ifdef WITH_TLS
        tls_client ws_client;
#else
        client ws_client;
#endif

        ws_client.init_asio(&io);

#ifdef WITH_TLS
        ws_client.set_tls_init_handler(
            [](websocketpp::connection_hdl hdl) {
                context_ptr ctx = std::make_shared<boost::asio::ssl::context>(boost::asio::ssl::context::tlsv1);
                try {
                    ctx->set_options(boost::asio::ssl::context::default_workarounds | boost::asio::ssl::context::no_sslv2 | boost::asio::ssl::context::single_dh_use);
                } catch (std::exception& e) {
                    std::cout << e.what() << std::endl;
                }

                return ctx;
            });

        std::cerr << "Connecting to " << DEFAULT_TLS_ENDPOINT << "...\n";
        auto transport = std::make_shared<autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_tls_client>>(
            ws_client, DEFAULT_TLS_ENDPOINT, debug);
#else
        std::cerr << "Connecting to " << DEFAULT_ENDPOINT << "...\n";
        auto transport = std::make_shared<autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_client>>(
            ws_client, DEFAULT_ENDPOINT, debug);
#endif

        auto session = std::make_shared<autobahn::wamp_session>(io, debug);

        // Create a thread to run the telemetry loop
        transport->attach(std::static_pointer_cast<autobahn::wamp_transport_handler>(session));

        boost::future<void> connect_future;
        boost::future<void> start_future;
        boost::future<void> join_future;
        boost::future<void> subscribe_future;

        connect_future = transport->connect().then([&](boost::future<void> connected) {
            try {
                connected.get();
            } catch (const std::exception& e) {
                std::cerr << e.what() << std::endl;
                io.stop();
                return;
            }

            std::cerr << "transport connected" << std::endl;

            start_future = session->start().then([&](boost::future<void> started) {
                try {
                    started.get();
                } catch (const std::exception& e) {
                    std::cerr << e.what() << std::endl;
                    io.stop();
                    return;
                }

                std::cerr << "session started" << std::endl;

                join_future = session->join(DEFAULT_REALM).then([&](boost::future<uint64_t> joined) {
                    try {
                        std::cerr << "joined realm: " << joined.get() << std::endl;
                    } catch (const std::exception& e) {
                        std::cerr << e.what() << std::endl;
                        io.stop();
                        return;
                    }

                    subscribe_future = session->subscribe(DEFAULT_TOPIC, [](const autobahn::wamp_event& event) {
                                                  using topic_type = std::unordered_map<std::string, size_t>;
                                                  auto ev = event.argument<topic_type>(0);
                                                  for (auto&& arg : ev) {
                                                      std::cerr << arg.first << " " << arg.second << std::endl;
                                                  }
                                              },
                                                  autobahn::wamp_subscribe_options("exact"))
                                           .then([&](boost::future<autobahn::wamp_subscription> subscription) {
                                               try {
                                                   std::cerr << "subscribed to topic:" << subscription.get().id() << std::endl;
                                               } catch (const std::exception& e) {
                                                   std::cerr << e.what() << std::endl;
                                                   io.stop();
                                                   return;
                                               }
                                           });

                });
            });
        });

        std::cerr << "starting io service" << std::endl;

        io.run();

        std::cerr << "stopped io service" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return -1;
    }

    return 0;
}
