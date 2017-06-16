#ifndef GA_SDK_CONTAINERS_HPP
#define GA_SDK_CONTAINERS_HPP
#pragma once

#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include <boost/algorithm/string.hpp>

#include <msgpack.hpp>

namespace ga {
namespace sdk {

    namespace detail {
        template <typename T> class object_container {
        public:
            using container = std::unordered_map<std::string, msgpack::object>;

            void associate(const container& data) { m_data = data; }

            template <typename U> U get(const std::string& path) const
            {
                std::vector<std::string> split;
                boost::algorithm::split(split, path, [](char c) { return c == '/'; });
                container v = m_data;
                auto p = split.begin();
                for (; p != split.end() - 1; ++p) {
                    v = v.at(*p).template as<container>();
                }
                return v.at(*p).template as<U>();
            }

            template <typename U> void set(const std::string& path, const U& u)
            {
                std::stringstream strm;
                msgpack::pack(strm, u);
                m_data[path] = msgpack::unpack(strm.str().data(), strm.str().size()).get();
            }

            bool empty() const { return m_data.empty(); }

        private:
            container m_data;
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
