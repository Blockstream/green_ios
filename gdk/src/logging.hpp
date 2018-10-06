#ifndef GA_SDK_LOGGING_HPP
#define GA_SDK_LOGGING_HPP
#pragma once

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

    BOOST_LOG_INLINE_GLOBAL_LOGGER_DEFAULT(gdk_logger, boost::log::sources::logger_mt)

#define GDK_LOG_NAMED_SCOPE(name)                                                                                      \
    BOOST_LOG_SEV(gdk_logger::get(), boost::log::trivial::info)                                                        \
        << __FILE__ << ':' << __LINE__ << ':' << name << ':' << __func__;

#define GDK_LOG_SEV(sev) BOOST_LOG_SEV(gdk_logger::get(), sev)

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
