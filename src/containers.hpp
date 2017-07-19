#ifndef GA_SDK_CONTAINERS_HPP
#define GA_SDK_CONTAINERS_HPP
#pragma once

#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include <boost/algorithm/string.hpp>

#include <msgpack.hpp>

#include "assertion.hpp"

namespace ga {
namespace sdk {

    namespace detail {
        template <typename T> class object_container {
        public:
            using container = std::unordered_map<std::string, msgpack::object>;
            using value_container = std::unordered_map<std::string, std::string>;

            void associate(const msgpack::object& o)
            {
                std::stringstream strm;
                strm << o;
                m_json = strm.str();
            }

            void associate(const container& data)
            {
                for (auto&& kv : data) {
                    std::stringstream strm;
                    msgpack::pack(strm, kv.second);
                    m_data[kv.first] = strm.str();
                }
            }

            template <typename U> U get(const std::string& path) const
            {
                std::vector<std::string> split;
                boost::algorithm::split(split, path, [](char c) { return c == '/'; });
                GA_SDK_RUNTIME_ASSERT(!split.empty());
                auto p = split.begin();
                const auto& stream = m_data.at(*p);
                const auto h = msgpack::unpack(stream.data(), stream.size());
                if (split.size() > 1) {
                    auto v = h.get().template as<container>();
                    ++p;
                    const auto end = split.end() - 1;
                    for (; p != end; ++p) {
                        v = v.at(*p).template as<container>();
                    }
                    return v.at(*p).template as<U>();
                } else {
                    return h.get().template as<U>();
                }
            }

            template <typename U> U get_with_default(const std::string& path, const U& u) const
            {
                try {
                    return get<U>(path);
                } catch (const std::exception& ex) {
                    return u;
                }
            }

            template <typename U> void set(const std::string& path, const U& u)
            {
                std::stringstream strm;
                msgpack::pack(strm, u);
                m_data[path] = strm.str();
            }

            bool empty() const { return m_data.empty(); }

            const std::string& get_json() const { return m_json; }

        private:
            value_container m_data;
            std::string m_json;
        };
    }

    struct login_data : public detail::object_container<login_data> {
    };

    struct receive_address : public detail::object_container<receive_address> {
    };

    struct tx_list : public detail::object_container<tx_list> {
    };

    struct utxo : public detail::object_container<utxo> {
    };
}
}

#endif
