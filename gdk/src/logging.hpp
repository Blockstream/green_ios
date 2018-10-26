#ifndef GA_SDK_LOGGING_HPP
#define GA_SDK_LOGGING_HPP
#pragma once

#ifdef __ANDROID__
#include <android/log.h>
#endif

#include "autobahn_wrapper.hpp"
#include "boost_wrapper.hpp"

namespace ga {
namespace sdk {
    namespace log_level = boost::log::trivial;
    namespace wlog = websocketpp::log;

    namespace {
        constexpr boost::log::trivial::severity_level sev(wlog::level l)
        {
            switch (l) {
            case wlog::alevel::devel:
            case wlog::elevel::devel:
            case wlog::elevel::library:
                return boost::log::trivial::debug;
            case wlog::elevel::warn:
                return boost::log::trivial::warning;
            case wlog::elevel::rerror:
                return boost::log::trivial::error;
            case wlog::elevel::fatal:
                return boost::log::trivial::fatal;
            case wlog::elevel::info:
            default:
                return boost::log::trivial::info;
            }
        }
    } // namespace

#ifdef __ANDROID__
    class android_backend : public boost::log::sinks::basic_formatted_sink_backend<char> {
    public:
        void consume(const boost::log::record_view&, const std::string& formatted_message)
        {
            // TODO: severity levels
            __android_log_print(ANDROID_LOG_DEBUG, "GASDK", "%s", formatted_message.c_str());
        }
    };

    BOOST_LOG_INLINE_GLOBAL_LOGGER_INIT(gdk_logger, boost::log::sources::logger_mt)
    {
        using sink_t = boost::log::sinks::asynchronous_sink<android_backend>;
        auto sink = boost::make_shared<sink_t>(boost::make_shared<android_backend>());
        boost::log::core::get()->add_sink(sink);
        return boost::log::sources::logger_mt{};
    }
#else
    BOOST_LOG_INLINE_GLOBAL_LOGGER_DEFAULT(gdk_logger, boost::log::sources::logger_mt)
#endif

#define GDK_LOG_NAMED_SCOPE(name)                                                                                      \
    BOOST_LOG_SEV(::ga::sdk::gdk_logger::get(), boost::log::trivial::info)                                             \
        << __FILE__ << ':' << __LINE__ << ':' << name << ':' << __func__;

#define GDK_LOG_SEV(sev) BOOST_LOG_SEV(::ga::sdk::gdk_logger::get(), ::ga::sdk::sev)

    class websocket_boost_logger {
    public:
        static boost::log::sources::logger_mt& m_log;

        explicit websocket_boost_logger(wlog::channel_type_hint::value hint)
            : websocket_boost_logger(0, hint)
        {
        }
        websocket_boost_logger(wlog::level l, wlog::channel_type_hint::value)
            : m_level(l)
        {
        }
        websocket_boost_logger()
            : websocket_boost_logger(0, 0)
        {
        }

        void set_channels(wlog::level l) { m_level = l; }
        void clear_channels(wlog::level) { m_level = 0; }
        void write(wlog::level l, const std::string& s)
        {
            if (dynamic_test(l)) {
                BOOST_LOG_SEV(m_log, sev(l)) << s;
            }
        }
        void write(wlog::level l, char const* s)
        {
            if (dynamic_test(l)) {
                BOOST_LOG_SEV(m_log, sev(l)) << s;
            }
        }
        bool static_test(wlog::level l) const { return (m_level & l) != 0; }
        bool dynamic_test(wlog::level l) { return (m_level & l) != 0; }

        wlog::level m_level;
    };
} // namespace sdk
} // namespace ga

#endif
