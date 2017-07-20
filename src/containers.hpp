#ifndef GA_SDK_CONTAINERS_HPP
#define GA_SDK_CONTAINERS_HPP
#pragma once

#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

#include <boost/algorithm/string.hpp>

#include <msgpack.hpp>

#include "amount.hpp"
#include "assertion.hpp"

namespace ga {
namespace sdk {

    namespace detail {
        template <typename T> class object_container {
        public:
            using container = std::map<std::string, msgpack::object>;
            using value_container = std::map<std::string, std::string>;

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
                    const auto end = split.end() - 1;
                    auto v = h.get().template as<container>();
                    while (++p != end) {
                        v = as(v, *p);
                    }
                    return as<U>(v, *p);
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
            container as(const container& v, const std::string& k) const { return v.at(k).as<container>(); }
            template <typename U> U as(const container& v, const std::string& k) const
            {
                return v.at(k).template as<U>();
            }

        protected:
            value_container m_data;
            std::string m_json;
        };
    }

    struct fee_estimates : public detail::object_container<fee_estimates> {
        fee_estimates& operator=(const container& data)
        {
            associate(data);
            return *this;
        }

        amount get_estimate(bool is_instant, uint32_t block) const;
    };

    class login_data : public detail::object_container<login_data> {
    public:
        const fee_estimates& get_estimates() const { return m_fee_estimates; }

        login_data& operator=(const container& data)
        {
            associate(data);
            const auto stream = m_data.at("fee_estimates");
            const auto h = msgpack::unpack(stream.data(), stream.size());
            m_fee_estimates = h.get().as<container>();
            return *this;
        }

    private:
        fee_estimates m_fee_estimates;
    };

    struct receive_address : public detail::object_container<receive_address> {
        receive_address& operator=(const container& data)
        {
            associate(data);
            return *this;
        }

        std::string get_address() const { return get_with_default("p2sh", get_with_default("p2wsh", std::string())); }
    };

    struct tx_list : public detail::object_container<tx_list> {
        tx_list& operator=(const container& data)
        {
            associate(data);
            return *this;
        }
    };

    struct utxo : public detail::object_container<utxo> {
        utxo& operator=(const container& data)
        {
            associate(data);
            return *this;
        }
    };
}
}

#endif
