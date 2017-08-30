#ifndef GA_SDK_CONTAINERS_HPP
#define GA_SDK_CONTAINERS_HPP
#pragma once

#include <memory>
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

    enum class transaction_type { in, out, redeposit };

    enum class script_type : int {
        p2sh_fortified_out = 10,
        p2sh_p2wsh_fortified_out = 14,
        redeem_p2sh_fortified = 150,
        redeem_p2sh_p2wsh_fortified = 159
    };

    namespace detail {
        template <typename T> class object_container {
        public:
            using container = std::map<std::string, msgpack::object>;
            using value_container = std::map<std::string, std::string>;

            void associate(const msgpack::object& o) { m_o = msgpack::clone(o); }

            template <typename U> U get(const std::string& path) const
            {
                std::vector<std::string> split;
                boost::algorithm::split(split, path, [](char c) { return c == '/'; });
                GA_SDK_RUNTIME_ASSERT(!split.empty());
                auto p = split.begin();
                const container& data = m_o.get().template as<container>();
                const auto h = data.at(*p);
                if (split.size() > 1) {
                    const auto end = split.end() - 1;
                    auto v = h.template as<container>();
                    while (++p != end) {
                        v = as(v, *p);
                    }
                    return as<U>(v, *p);
                } else {
                    return h.template as<U>();
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
                auto o = m_o.get().template as<container>();
                o[path] = u;
                msgpack::zone z;
                associate(msgpack::object(o, z));
            }

            bool empty() const { return false; }

            std::string get_json() const
            {
                std::stringstream strm;
                strm << m_o.get();
                return strm.str();
            }

            const msgpack::object_handle& get_handle() const { return m_o; }

        protected:
            container as(const container& v, const std::string& k) const { return v.at(k).as<container>(); }
            template <typename U> U as(const container& v, const std::string& k) const
            {
                return v.at(k).template as<U>();
            }

            msgpack::object_handle m_o;
        };
    }

    struct fee_estimates : public detail::object_container<fee_estimates> {
        fee_estimates& operator=(const msgpack::object& data)
        {
            associate(data);
            return *this;
        }

        amount get_estimate(bool is_instant, uint32_t block) const;
    };

    class login_data : public detail::object_container<login_data> {
    public:
        const fee_estimates& get_estimates() const { return m_fee_estimates; }

        login_data& operator=(const msgpack::object& data)
        {
            associate(data);
            m_fee_estimates = get<msgpack::object>("fee_estimates");
            return *this;
        }

    private:
        fee_estimates m_fee_estimates;
    };

    struct receive_address : public detail::object_container<receive_address> {
        receive_address& operator=(const msgpack::object& data)
        {
            associate(data);
            return *this;
        }

        std::string get_address() const { return get_with_default("p2sh", get_with_default("p2wsh", std::string())); }
    };

    struct tx : public detail::object_container<tx> {
        struct tx_view {
            std::vector<std::string> received_on;
            std::string counterparty;
            std::string hash;
            std::string double_spent_by;
            amount value;
            amount fee;
            size_t block_height;
            size_t size;
            transaction_type type;
            bool instant;
            bool replaceable;
            bool is_spent;
        };

        tx& operator=(const msgpack_object& data)
        {
            associate(data);
            return *this;
        }

        tx_view populate_view() const;
    };

    class tx_list : public detail::object_container<tx_list> {
    public:
        using value_container = std::vector<msgpack::object>;
        using const_iterator = value_container::const_iterator;
        using size_type = value_container::size_type;

        tx_list& operator=(const msgpack_object& data)
        {
            associate(data);
            m_list = get<std::vector<msgpack::object>>("list");
            return *this;
        }

        const_iterator begin() const { return m_list.begin(); }
        const_iterator end() const { return m_list.end(); }

        tx operator[](size_t i) const
        {
            tx t;
            t = m_list[i];
            return t;
        }

        size_type size() const { return m_list.size(); }

    private:
        value_container m_list;
    };

    struct utxo : public detail::object_container<utxo> {
        utxo& operator=(const msgpack_object& data)
        {
            associate(data);
            return *this;
        }
    };

    struct balance : public detail::object_container<balance> {
        balance& operator=(const msgpack_object& data)
        {
            associate(data);
            return *this;
        }
    };

    struct two_factor : public detail::object_container<two_factor> {
        two_factor& operator=(const msgpack_object& data)
        {
            associate(data);
            return *this;
        }
    };

    using pin_info = std::map<std::string, std::string>;
}
}

#endif
