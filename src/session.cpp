#include <thread>
#include <unordered_map>

#include <autobahn/autobahn.hpp>
#include <autobahn/wamp_websocketpp_websocket_transport.hpp>

#include <websocketpp/client.hpp>
#include <websocketpp/config/asio_client.hpp>
#include <websocketpp/config/asio_no_tls_client.hpp>

#include "session.hpp"

namespace ga {
namespace sdk {

#ifdef WITH_TLS
    using client = websocketpp::client<websocketpp::config::asio_tls_client>;
    using transport = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_tls_client>;
#else
    using transport = autobahn::wamp_websocketpp_websocket_transport<websocketpp::config::asio_client>;
    using client = websocketpp::client<websocketpp::config::asio_client>;
#endif

    using context_ptr = websocketpp::lib::shared_ptr<boost::asio::ssl::context>;

    const std::string DEFAULT_REALM("realm1");

    struct event_loop_controller {
        explicit event_loop_controller(boost::asio::io_service& io)
            : _work_guard(std::make_unique<boost::asio::io_service::work>(io))
        {
            _run_thread = std::move(std::thread([&] { io.run(); }));
        }

        ~event_loop_controller()
        {
            _work_guard.reset();
            _run_thread.join();
        }

        std::thread _run_thread;
        std::unique_ptr<boost::asio::io_service::work> _work_guard;
    };

    class session::session_impl {
    public:
        explicit session_impl(bool debug)
            : _controller(_io)
            , _debug(debug)
        {
            _client.init_asio(&_io);
        }

        ~session_impl()
        {
            _io.stop();
        }

        void connect(const std::string& endpoint);

    private:
        boost::asio::io_service _io;
        client _client;
        std::unique_ptr<transport> _transport;
        std::shared_ptr<autobahn::wamp_session> _session;

        event_loop_controller _controller;

        bool _debug;
    };

    void session::session_impl::connect(const std::string& endpoint)
    {
        if (_transport || _session) {
            return;
        }

        _session = std::make_shared<autobahn::wamp_session>(_io, _debug);

        _transport = std::make_unique<transport>(_client, endpoint, _debug);
        _transport->attach(std::static_pointer_cast<autobahn::wamp_transport_handler>(_session));

        boost::future<void> connect_future;
        boost::future<void> start_future;
        boost::future<void> join_future;

        connect_future = _transport->connect().then([&](boost::future<void> connected) {
            connected.get();
            start_future = _session->start().then([&](boost::future<void> started) {
                started.get();

                join_future = _session->join(DEFAULT_REALM).then([&](boost::future<uint64_t> joined) {
                    joined.get();
                });
            });
        });

        connect_future.get();
    }

    void session::connect(const std::string& endpoint, bool debug)
    {
        _impl = std::make_shared<session::session_impl>(debug);

        try {
            _impl->connect(endpoint);
        } catch (const std::exception& ex) {
            std::cerr << ex.what() << std::endl;
        }
    }

    void session::disconnect()
    {
        _impl.reset();
    }
}
}
