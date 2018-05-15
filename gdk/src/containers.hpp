#ifndef GA_SDK_CONTAINERS_HPP
#define GA_SDK_CONTAINERS_HPP
#pragma once

#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

#include "boost_wrapper.hpp"
#include "msgpack_wrapper.hpp"

#include "amount.hpp"
#include "assertion.hpp"

namespace ga {
namespace sdk {

    enum class transaction_type : uint8_t { in, out, redeposit };

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
                }
                return h.template as<U>();
            }

            template <typename U> U get_with_default(const std::string& path, const U& u = U()) const
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
            template <typename U> U handle_as() const { return m_o.get().template as<U>(); }

            msgpack::object_handle m_o;
        };
    }

    class fee_estimates : public detail::object_container<fee_estimates> {
    public:
        fee_estimates& operator=(const msgpack::object& data);

        amount get_estimate(uint32_t block, bool instant, amount min_fee_rate, bool main_net);

    private:
        std::mutex m_mutex;
    };

    struct subaccount : public detail::object_container<subaccount> {
        subaccount(const msgpack::object& other) { associate(other); }

        subaccount& operator=(const msgpack::object& data)
        {
            associate(data);
            return *this;
        }
    };

    struct login_data : public detail::object_container<login_data> {
        login_data() = default;

        login_data(const login_data& data) { associate(data.get_handle().get()); }

        login_data& operator=(const msgpack::object& data)
        {
            associate(data);
            return *this;
        }

        uint32_t get_min_unused_pointer() const;

        std::vector<subaccount> get_subaccounts() const;
        void insert_subaccount(const std::string& name, uint32_t pointer, const std::string& receiving_id,
            const std::string& recovery_pub_key, const std::string& recovery_chain_code, const std::string& type);
    };

    struct receive_address : public detail::object_container<receive_address> {
        receive_address& operator=(const msgpack::object& data)
        {
            associate(data);
            return *this;
        }

        std::string get_address() const { return get_with_default("p2sh", get_with_default("p2wsh", std::string())); }
    };

    class tx : public detail::object_container<tx> {
    public:
        tx& operator=(const msgpack_object& data)
        {
            construct_from(data);
            return *this;
        }

    private:
        void construct_from(const msgpack_object& data);
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
        utxo() = default;

        utxo(const msgpack_object& other) { associate(other); }

        utxo& operator=(const msgpack_object& other)
        {
            associate(other);
            return *this;
        }
    };

    struct utxo_set : public detail::object_container<utxo_set> {
        using value_container = std::vector<msgpack::object>;
        using const_iterator = value_container::const_iterator;
        using size_type = value_container::size_type;

        utxo_set& operator=(const msgpack_object& data)
        {
            associate(data);
            m_container = handle_as<value_container>();
            return *this;
        }

        const_iterator begin() const { return m_container.begin(); }
        const_iterator end() const { return m_container.end(); }

        utxo operator[](size_t i) const
        {
            utxo u;
            u = m_container[i];
            return u;
        }

        size_type size() const { return m_container.size(); }

        value_container m_container;
    };

    struct balance : public detail::object_container<balance> {
        balance& operator=(const msgpack_object& data)
        {
            associate(data);
            return *this;
        }
    };

    struct available_currencies : public detail::object_container<available_currencies> {
        available_currencies& operator=(const msgpack_object& data)
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

    struct block_event : public detail::object_container<block_event> {
        block_event& operator=(const msgpack_object& data)
        {
            associate(data);
            return *this;
        }
    };

    struct bitcoin_uri : public detail::object_container<bitcoin_uri> {
        bitcoin_uri()
        {
            container c;
            msgpack::zone z;
            associate(msgpack::object(c, z));
        }
    };

    using pin_info = std::map<std::string, std::string>;
}
}

#endif
