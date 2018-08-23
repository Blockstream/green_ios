#include "amount.hpp"
#include "assertion.hpp"
#include "common.h"
#include "exception.hpp"
#include "session.h"
#include "session.hpp"
#include "twofactor.h"
#include "twofactor.hpp"

namespace {

template <typename... Args> auto assert_invoke_args(__attribute__((unused)) Args&&... args) {}

template <typename Obj, typename... Args> auto assert_invoke_args(Obj* obj, __attribute__((unused)) Args&&... args)
{
    GA_SDK_RUNTIME_ASSERT(obj);
}

template <typename F, typename... Args> auto c_invoke(F&& f, Args&&... args)
{
    try {
        assert_invoke_args(std::forward<Args>(args)...);
        f(std::forward<Args>(args)...);
        return GA_OK;
    } catch (const autobahn::no_session_error& e) {
        return GA_SESSION_LOST;
    } catch (const ga::sdk::reconnect_error& ex) {
        return GA_RECONNECT;
    } catch (const ga::sdk::timeout_error& ex) {
        return GA_TIMEOUT;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
}

char* to_c_string(const std::string& s)
{
    auto* str = new char[s.size() + 1];
    std::copy(s.begin(), s.end(), str);
    *(str + s.size()) = 0;
    return str;
}
} // namespace

struct GA_session final : public ga::sdk::session {
};

struct GA_dict final : public ga::sdk::detail::object_container<GA_dict> {
};

struct GA_tx final : public ga::sdk::tx {
    GA_tx& operator=(const msgpack::object& data)
    {
        ga::sdk::tx::operator=(data);
        return *this;
    }
};

struct GA_tx_list final : public ga::sdk::tx_list {
    GA_tx_list& operator=(const msgpack::object& data)
    {
        ga::sdk::tx_list::operator=(data);
        return *this;
    }
};

struct GA_balance final : public ga::sdk::balance {
    GA_balance& operator=(const msgpack::object& data)
    {
        ga::sdk::balance::operator=(data);
        return *this;
    }
};

struct GA_available_currencies final : public ga::sdk::available_currencies {
    GA_available_currencies& operator=(const msgpack::object& data)
    {
        ga::sdk::available_currencies::operator=(data);
        return *this;
    }
};

struct GA_login_data final : public ga::sdk::login_data {
    GA_login_data& operator=(const msgpack::object& data)
    {
        ga::sdk::login_data::operator=(data);
        return *this;
    }
};

struct GA_system_message final : public ga::sdk::system_message {
    GA_system_message& operator=(const msgpack::object& data)
    {
        ga::sdk::system_message::operator=(data);
        return *this;
    }
};

struct GA_twofactor_config final : public ga::sdk::twofactor_config {
    GA_twofactor_config& operator=(const msgpack::object& data)
    {
        ga::sdk::twofactor_config::operator=(data);
        return *this;
    }
};

struct GA_twofactor_data final : public ga::sdk::twofactor_data {
    GA_twofactor_data& operator=(const msgpack::object& data)
    {
        ga::sdk::twofactor_data::operator=(data);
        return *this;
    }
};

#define GA_SDK_DEFINE_C_FUNCTION_1(NAME, T1, A1, BODY)                                                                 \
    int NAME(T1 A1) { return c_invoke([](T1 A1) BODY, A1); }

#define GA_SDK_DEFINE_C_FUNCTION_2(NAME, T1, A1, T2, A2, BODY)                                                         \
    int NAME(T1 A1, T2 A2) { return c_invoke([](T1 A1, T2 A2) BODY, A1, A2); }

#define GA_SDK_DEFINE_C_FUNCTION_3(NAME, T1, A1, T2, A2, T3, A3, BODY)                                                 \
    int NAME(T1 A1, T2 A2, T3 A3) { return c_invoke([](T1 A1, T2 A2, T3 A3) BODY, A1, A2, A3); }

#define GA_SDK_DEFINE_C_FUNCTION_4(NAME, T1, A1, T2, A2, T3, A3, T4, A4, BODY)                                         \
    int NAME(T1 A1, T2 A2, T3 A3, T4 A4) { return c_invoke([](T1 A1, T2 A2, T3 A3, T4 A4) BODY, A1, A2, A3, A4); }

#define GA_SDK_DEFINE_C_FUNCTION_5(NAME, T1, A1, T2, A2, T3, A3, T4, A4, T5, A5, BODY)                                 \
    int NAME(T1 A1, T2 A2, T3 A3, T4 A4, T5 A5)                                                                        \
    {                                                                                                                  \
        return c_invoke([](T1 A1, T2 A2, T3 A3, T4 A4, T5 A5) BODY, A1, A2, A3, A4, A5);                               \
    }

#define GA_SDK_DEFINE_C_FUNCTION_6(NAME, T1, A1, T2, A2, T3, A3, T4, A4, T5, A5, T6, A6, BODY)                         \
    int NAME(T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6)                                                                 \
    {                                                                                                                  \
        return c_invoke([](T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6) BODY, A1, A2, A3, A4, A5, A6);                    \
    }

#define GA_SDK_DEFINE_C_FUNCTION_7(NAME, T1, A1, T2, A2, T3, A3, T4, A4, T5, A5, T6, A6, T7, A7, BODY)                 \
    int NAME(T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7)                                                          \
    {                                                                                                                  \
        return c_invoke([](T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7) BODY, A1, A2, A3, A4, A5, A6, A7);         \
    }

#define GA_SDK_DEFINE_C_FUNCTION_8(NAME, T1, A1, T2, A2, T3, A3, T4, A4, T5, A5, T6, A6, T7, A7, T8, A8, BODY)         \
    int NAME(T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7, T8 A8)                                                   \
    {                                                                                                                  \
        return c_invoke([](T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7, T8 A8) BODY, A1, A2, A3, A4, A5, A6, A7,   \
            A8);                                                                                                       \
    }

int GA_create_session(struct GA_session** session)
{
    try {
        GA_SDK_RUNTIME_ASSERT(session);
        *session = new GA_session();
        return GA_OK;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
}

int GA_destroy_session(struct GA_session* session)
{
    delete session;
    return GA_OK;
}

void GA_destroy_dict(struct GA_dict* dict) { delete dict; }

int GA_destroy_tx_list(struct GA_tx_list* txs)
{
    delete txs;
    return GA_OK;
}

int GA_destroy_tx(const struct GA_tx* tx)
{
    delete tx;
    return GA_OK;
}

int GA_destroy_balance(const struct GA_balance* balance)
{
    delete balance;
    return GA_OK;
}

int GA_destroy_available_currencies(const struct GA_available_currencies* o)
{
    delete o;
    return GA_OK;
}

int GA_destroy_login_data(const struct GA_login_data* login_data)
{
    delete login_data;
    return GA_OK;
}

int GA_destroy_twofactor_config(const struct GA_twofactor_config* twofactor_config)
{
    delete twofactor_config;
    return GA_OK;
}

int GA_destroy_twofactor_data(const struct GA_twofactor_data* twofactor_data)
{
    delete twofactor_data;
    return GA_OK;
}

GA_SDK_DEFINE_C_FUNCTION_3(GA_connect, struct GA_session*, session, uint32_t, network, uint32_t, debug,
    { return GA_connect_with_proxy(session, network, "", GA_NO_TOR, debug); })

GA_SDK_DEFINE_C_FUNCTION_5(GA_connect_with_proxy, struct GA_session*, session, uint32_t, network, const char*,
    proxy_uri, uint32_t, use_tor, uint32_t, debug, {
        GA_SDK_RUNTIME_ASSERT(proxy_uri);
        auto&& params = [](uint32_t network, const std::string& proxy_uri, bool use_tor) {
            switch (network) {
            case GA_NETWORK_MAINNET:
                return ga::sdk::make_mainnet_network(proxy_uri, use_tor);
            case GA_NETWORK_TESTNET:
                return ga::sdk::make_testnet_network(proxy_uri, use_tor);
            case GA_NETWORK_LOCALTEST:
                return ga::sdk::make_localtest_network(proxy_uri, use_tor);
            case GA_NETWORK_REGTEST:
                return ga::sdk::make_regtest_network(proxy_uri, use_tor);
            default:
                GA_SDK_RUNTIME_ASSERT(false);
                __builtin_unreachable();
            }
        }(network, proxy_uri, use_tor == GA_USE_TOR);

        session->connect(std::move(params), debug != GA_FALSE);
    })

GA_SDK_DEFINE_C_FUNCTION_1(GA_disconnect, struct GA_session*, session, { session->disconnect(); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_register_user, struct GA_session*, session, const char*, mnemonic, {
    GA_SDK_RUNTIME_ASSERT(mnemonic);
    session->register_user(mnemonic);
})

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_login, struct GA_session*, session, const char*, mnemonic, struct GA_login_data**, login_data, {
        GA_SDK_RUNTIME_ASSERT(mnemonic);
        GA_SDK_RUNTIME_ASSERT(login_data);
        const auto result = session->login(mnemonic);
        *login_data = new GA_login_data;
        **login_data = result.get_handle().get();
    })

GA_SDK_DEFINE_C_FUNCTION_5(GA_login_with_pin, struct GA_session*, session, const char*, pin, const char*,
    pin_identifier, const char*, secret, struct GA_login_data**, login_data, {
        GA_SDK_RUNTIME_ASSERT(pin);
        GA_SDK_RUNTIME_ASSERT(pin_identifier);
        GA_SDK_RUNTIME_ASSERT(secret);
        GA_SDK_RUNTIME_ASSERT(login_data);
        const auto result = session->login(pin, std::make_pair(pin_identifier, secret));
        *login_data = new GA_login_data;
        **login_data = result.get_handle().get();
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_get_system_message, struct GA_session*, session, uint32_t*, message_id, const char**, message_text, {
        GA_SDK_RUNTIME_ASSERT(message_id);
        GA_SDK_RUNTIME_ASSERT(message_text);
        const auto message = session->get_system_message(*message_id);
        *message_text = to_c_string(message.get<std::string>("message"));
        *message_id = message.get_with_default<uint32_t>("next_message_id", 0);
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_ack_system_message, struct GA_session*, session, uint32_t, message_id, const char*, message_text, {
        GA_SDK_RUNTIME_ASSERT(message_text);
        session->ack_system_message(message_id, message_text);
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_twofactor_config, struct GA_session*, session, struct GA_twofactor_config**, config, {
    GA_SDK_RUNTIME_ASSERT(config);
    const auto result = session->get_twofactor_config();
    *config = new GA_twofactor_config;
    **config = result.get_handle().get();
})

GA_SDK_DEFINE_C_FUNCTION_8(GA_send, struct GA_session*, session, uint32_t, subaccount, const char**, addr, size_t,
    addr_siz, const uint64_t*, amt, size_t, amt_siz, uint64_t, fee_rate, uint32_t, send_all, {
        GA_SDK_RUNTIME_ASSERT(addr);
        GA_SDK_RUNTIME_ASSERT(amt);
        GA_SDK_RUNTIME_ASSERT(addr_siz == amt_siz);
        GA_SDK_RUNTIME_ASSERT(send_all == GA_TRUE || send_all == GA_FALSE);
        std::vector<ga::sdk::session::address_amount_pair> addr_amt;
        addr_amt.reserve(addr_siz);
        for (size_t i = 0; i < addr_siz; ++i) {
            GA_SDK_RUNTIME_ASSERT(addr[i]);
            addr_amt.emplace_back(std::make_pair(addr[i], ga::sdk::amount{ amt[i] }));
        }
        if (subaccount == GA_ALL_ACCOUNTS) {
            session->send(addr_amt, ga::sdk::amount{ fee_rate }, send_all == GA_TRUE);
        } else {
            session->send(subaccount, addr_amt, ga::sdk::amount{ fee_rate }, send_all == GA_TRUE);
        }
    })

GA_SDK_DEFINE_C_FUNCTION_4(GA_set_transaction_memo, struct GA_session*, session, const char*, txhash_hex, const char*,
    memo, uint32_t, memo_type, {
        GA_SDK_RUNTIME_ASSERT(txhash_hex);
        GA_SDK_RUNTIME_ASSERT(memo);
        GA_SDK_RUNTIME_ASSERT(memo_type == GA_MEMO_USER || memo_type == GA_MEMO_BIP70);
        const std::string memo_type_str = memo_type == GA_MEMO_USER ? "user" : "payreq";
        session->set_transaction_memo(txhash_hex, memo, memo_type_str);
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_set_pricing_source, struct GA_session*, session, const char*, currency, const char*, exchange, {
        GA_SDK_RUNTIME_ASSERT(currency);
        GA_SDK_RUNTIME_ASSERT(exchange);
        session->set_pricing_source(currency, exchange);
    })

using callback_t = void (*)(void*, char* output);

GA_SDK_DEFINE_C_FUNCTION_4(GA_subscribe_to_topic_as_json, struct GA_session*, session, const char*, topic, callback_t,
    callback, void*, context, {
        GA_SDK_RUNTIME_ASSERT(topic);
        GA_SDK_RUNTIME_ASSERT(callback);
        GA_SDK_RUNTIME_ASSERT(context);
        session->subscribe(
            topic, [callback, context](const std::string& event) { callback(context, to_c_string(event)); });
    })

GA_SDK_DEFINE_C_FUNCTION_4(GA_login_watch_only, struct GA_session*, session, const char*, username, const char*,
    password, struct GA_login_data**, login_data, {
        GA_SDK_RUNTIME_ASSERT(username);
        GA_SDK_RUNTIME_ASSERT(password);
        GA_SDK_RUNTIME_ASSERT(login_data);
        const auto result = session->login_watch_only(username, password);
        *login_data = new GA_login_data;
        **login_data = result.get_handle().get();
    })

GA_SDK_DEFINE_C_FUNCTION_1(GA_remove_account, struct GA_session*, session, { session->remove_account(); })

GA_SDK_DEFINE_C_FUNCTION_5(GA_create_subaccount, struct GA_session*, session, uint32_t, type, const char*, name, char**,
    recovery_mnemonic, char**, recovery_xpub, {
        namespace sdk = ga::sdk;

        GA_SDK_RUNTIME_ASSERT(type == GA_2OF2 || type == GA_2OF3);
        GA_SDK_RUNTIME_ASSERT(name);
        GA_SDK_RUNTIME_ASSERT(type == GA_2OF2 || recovery_mnemonic);
        GA_SDK_RUNTIME_ASSERT(type == GA_2OF2 || recovery_xpub);

        std::string rec_mnemonic;
        std::string rec_xpub;
        std::tie(rec_mnemonic, rec_xpub) = session->create_subaccount(
            type == GA_2OF2 ? sdk::subaccount_type::_2of2 : sdk::subaccount_type::_2of3, name);
        if (type == GA_2OF3) {
            *recovery_mnemonic = to_c_string(rec_mnemonic);
            *recovery_xpub = to_c_string(rec_xpub);
        }
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_change_settings_privacy_send_me, struct GA_session*, session, uint32_t, value, {
    namespace sdk = ga::sdk;
    GA_SDK_RUNTIME_ASSERT(value == GA_PRIVATE || value == GA_ADDRBOOK || value == GA_PUBLIC);
    session->change_settings_privacy_send_me(sdk::privacy_send_me(value));
})

GA_SDK_DEFINE_C_FUNCTION_2(GA_change_settings_privacy_show_as_sender, struct GA_session*, session, uint32_t, value, {
    namespace sdk = ga::sdk;
    GA_SDK_RUNTIME_ASSERT(value == GA_PRIVATE || value == GA_ADDRBOOK || value == GA_PUBLIC);
    session->change_settings_privacy_show_as_sender(sdk::privacy_show_as_sender(value));
})

GA_SDK_DEFINE_C_FUNCTION_4(
    GA_change_settings_tx_limits, struct GA_session*, session, uint32_t, is_fiat, uint32_t, per_tx, uint32_t, total, {
        namespace sdk = ga::sdk;
        GA_SDK_RUNTIME_ASSERT(is_fiat == GA_FALSE || is_fiat == GA_TRUE);
        session->change_settings_tx_limits(is_fiat == GA_TRUE, per_tx, total);
    })

GA_SDK_DEFINE_C_FUNCTION_8(GA_get_tx_list, struct GA_session*, session, uint32_t, subaccount, time_t, begin_date,
    time_t, end_date, uint32_t, sort_by, uint32_t, page_id, const char*, query, struct GA_tx_list**, txs, {
        using namespace ga::sdk::literals;
        namespace sdk = ga::sdk;
        sdk::tx_list_sort_by sort_by_str;
        switch (sort_by) {
        case GA_TIMESTAMP:
            sort_by_str = ' '_ts;
            break;
        case GA_TIMESTAMP_ASCENDING:
            sort_by_str = '+'_ts;
            break;
        case GA_TIMESTAMP_DESCENDING:
            sort_by_str = '-'_ts;
            break;
        case GA_VALUE:
            sort_by_str = ' '_value;
            break;
        case GA_VALUE_ASCENDING:
            sort_by_str = '+'_value;
            break;
        case GA_VALUE_DESCENDING:
            sort_by_str = '-'_value;
            break;
        default:
            GA_SDK_RUNTIME_ASSERT(false);
            __builtin_unreachable();
        }
        GA_SDK_RUNTIME_ASSERT(txs);
        const std::string query_str = query ? query : std::string();

        const auto date_range = std::make_pair(begin_date, end_date);
        ga::sdk::tx_list result;
        if (subaccount == GA_ALL_ACCOUNTS) {
            result = session->get_tx_list(date_range, sort_by_str, page_id, query_str);
        } else {
            result = session->get_tx_list(subaccount, date_range, sort_by_str, page_id, query_str);
        }
        *txs = new GA_tx_list;
        GA_SDK_RUNTIME_ASSERT(*txs);
        **txs = result.get_handle().get();
    })

GA_SDK_DEFINE_C_FUNCTION_4(
    GA_get_receive_address, struct GA_session*, session, uint32_t, subaccount, uint32_t, addr_type, char**, address, {
        namespace sdk = ga::sdk;
        GA_SDK_RUNTIME_ASSERT(address);
        sdk::address_type type;
        if (addr_type == GA_ADDRESS_TYPE_CSV) {
            type = sdk::address_type::csv;
        } else if (addr_type == GA_ADDRESS_TYPE_P2WSH) {
            type = sdk::address_type::p2wsh;
        } else if (addr_type == GA_ADDRESS_TYPE_P2SH) {
            type = sdk::address_type::p2sh;
        } else if (addr_type == GA_ADDRESS_TYPE_DEFAULT) {
            type = session->get_default_address_type();
        } else {
            GA_SDK_RUNTIME_ASSERT(false);
            __builtin_unreachable();
        }
        const auto r = session->get_receive_address(subaccount, type);
        const auto a = r.get_address();
        *address = to_c_string(a);
    })

GA_SDK_DEFINE_C_FUNCTION_4(GA_get_balance, struct GA_session*, session, uint32_t, subaccount, uint32_t, num_confs,
    struct GA_balance**, balance, {
        GA_SDK_RUNTIME_ASSERT(balance);
        ga::sdk::balance result;
        if (subaccount == GA_ALL_ACCOUNTS) {
            result = session->get_balance(num_confs);
        } else {
            result = session->get_balance(subaccount, num_confs);
        }
        *balance = new GA_balance;
        **balance = result.get_handle().get();
    })

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_get_available_currencies, struct GA_session*, session, struct GA_available_currencies**, available_currencies, {
        GA_SDK_RUNTIME_ASSERT(available_currencies);
        const auto result = session->get_available_currencies();
        *available_currencies = new GA_available_currencies;
        **available_currencies = result.get_handle().get();
    })

GA_SDK_DEFINE_C_FUNCTION_6(GA_set_pin, struct GA_session*, session, const char*, mnemonic, const char*, pin,
    const char*, device, char**, pin_identifier, char**, secret, {
        GA_SDK_RUNTIME_ASSERT(mnemonic);
        GA_SDK_RUNTIME_ASSERT(pin);
        GA_SDK_RUNTIME_ASSERT(device);
        GA_SDK_RUNTIME_ASSERT(pin_identifier);
        GA_SDK_RUNTIME_ASSERT(secret);
        const auto p = session->set_pin(mnemonic, pin, device);
        *pin_identifier = to_c_string(p.at("pin_identifier"));
        *secret = to_c_string(p.at("secret"));
    })

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_convert_twofactor_config_to_json, struct GA_twofactor_config*, twofactor_config, char**, output, {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto v = twofactor_config->get_json();
        *output = to_c_string(v);
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_convert_tx_list_path_to_dict, struct GA_tx_list*, txs, const char*, path, struct GA_dict**, value, {
        GA_SDK_RUNTIME_ASSERT(path);
        GA_SDK_RUNTIME_ASSERT(value);
        const auto v = txs->get<msgpack::object>(path);
        *value = new struct GA_dict();
        (*value)->associate(v);
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_tx_list_to_json, struct GA_tx_list*, txs, char**, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    const auto v = txs->get_json();
    *output = to_c_string(v);
})

GA_SDK_DEFINE_C_FUNCTION_2(GA_tx_list_get_size, struct GA_tx_list*, txs, size_t*, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    *output = txs->size();
})

GA_SDK_DEFINE_C_FUNCTION_3(GA_tx_list_get_tx, struct GA_tx_list*, txs, size_t, i, struct GA_tx**, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    GA_SDK_RUNTIME_ASSERT(i < txs->size());
    *output = new GA_tx;
    **output = *(txs->begin() + i);
})

GA_SDK_DEFINE_C_FUNCTION_2(GA_transaction_to_json, struct GA_tx*, tx, char**, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    const auto v = tx->get_json();
    *output = to_c_string(v);
})

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_balance_to_json, struct GA_balance*, balance, char**, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    const auto v = balance->get_json();
    *output = to_c_string(v);
})

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_convert_available_currencies_to_json, struct GA_available_currencies*, currencies, char**, output, {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto v = currencies->get_json();
        *output = to_c_string(v);
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_login_data_to_json, struct GA_login_data*, login_data, char**, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    const auto v = login_data->get_json();
    *output = to_c_string(v);
})

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_convert_twofactor_data_from_json, const char*, input, struct GA_twofactor_data**, twofactor_data, {
        GA_SDK_RUNTIME_ASSERT(twofactor_data);
        *twofactor_data = new GA_twofactor_data;
        (*twofactor_data)->from_json(input);
    });

// twofactor.h
//

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_factor_list_get_size, struct GA_twofactor_factor_list*, factors, size_t*, output, {
        GA_SDK_RUNTIME_ASSERT(output);
        *output = factors->size();
    });

GA_SDK_DEFINE_C_FUNCTION_3(GA_twofactor_factor_list_get_factor, struct GA_twofactor_factor_list*, factors, size_t, i,
    struct GA_twofactor_factor**, output, {
        GA_SDK_RUNTIME_ASSERT(output);
        *output = new GA_twofactor_factor((*factors)[i]);
    });

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_get_factors, struct GA_twofactor_call*, call, struct GA_twofactor_factor_list**, output, {
        GA_SDK_RUNTIME_ASSERT(output);
        *output = new GA_twofactor_factor_list(call->get_twofactor_factors());
    });

GA_SDK_DEFINE_C_FUNCTION_1(
    GA_destroy_twofactor_factor_list, struct GA_twofactor_factor_list*, factors, { delete factors; });

//

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_factor_type, const struct GA_twofactor_factor*, factor, const char**, type, {
    GA_SDK_RUNTIME_ASSERT(type);
    *type = factor->get_type().c_str();
});

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_request_code, const struct GA_twofactor_factor*, factor, struct GA_twofactor_call*, call, {
        GA_SDK_RUNTIME_ASSERT(call);
        call->request_code(*factor);
    });

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_resolve_code, struct GA_twofactor_call*, call, const char*, code, {
    GA_SDK_RUNTIME_ASSERT(code);
    call->resolve_code(code);
});

GA_SDK_DEFINE_C_FUNCTION_1(GA_twofactor_call, struct GA_twofactor_call*, call, { (*call)(); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_next, struct GA_twofactor_call*, call, struct GA_twofactor_call**, next, {
    GA_SDK_RUNTIME_ASSERT(next);
    *next = call->get_next_call();
});

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_twofactor_set_email, struct GA_session*, session, const char*, email, struct GA_twofactor_call**, call, {
        GA_SDK_RUNTIME_ASSERT(email);
        GA_SDK_RUNTIME_ASSERT(call);
        *call = new GA_set_email_call(*session, email);
    });

GA_SDK_DEFINE_C_FUNCTION_4(GA_twofactor_enable, struct GA_session*, session, const char*, factor, const char*, data,
    struct GA_twofactor_call**, call, {
        GA_SDK_RUNTIME_ASSERT(factor);
        GA_SDK_RUNTIME_ASSERT(call);
        if (strcmp(factor, "gauth") == 0) {
            // gauth is slightly different to the other factors and has its own
            // implementation
            *call = new GA_init_enable_gauth_call(*session);
        } else {
            GA_SDK_RUNTIME_ASSERT(data);
            *call = new GA_init_enable_twofactor(*session, factor, data);
        }
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_twofactor_disable, struct GA_session*, session, const char*, factor, struct GA_twofactor_call**, call, {
        GA_SDK_RUNTIME_ASSERT(factor);
        GA_SDK_RUNTIME_ASSERT(call);
        *call = new GA_disable_twofactor(*session, factor);
    });

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_twofactor_change_tx_limits, struct GA_session*, session, const char*, total, struct GA_twofactor_call**, call, {
        GA_SDK_RUNTIME_ASSERT(session);
        GA_SDK_RUNTIME_ASSERT(total);
        GA_SDK_RUNTIME_ASSERT(call);
        *call = new GA_change_tx_limits_call(*session, total);
    });

GA_SDK_DEFINE_C_FUNCTION_8(GA_twofactor_send, struct GA_session*, session, const char**, addr, size_t, addr_siz,
    const uint64_t*, amt, size_t, amt_siz, uint64_t, fee_rate, int, send_all, struct GA_twofactor_call**, call, {
        GA_SDK_RUNTIME_ASSERT(session);
        GA_SDK_RUNTIME_ASSERT(addr);
        GA_SDK_RUNTIME_ASSERT(amt);
        GA_SDK_RUNTIME_ASSERT(addr_siz == amt_siz);
        std::vector<ga::sdk::session::address_amount_pair> addr_amt;
        addr_amt.reserve(addr_siz);
        for (size_t i = 0; i < addr_siz; ++i) {
            GA_SDK_RUNTIME_ASSERT(addr[i]);
            addr_amt.emplace_back(std::make_pair(addr[i], ga::sdk::amount{ amt[i] }));
        }
        *call = new GA_send_call(*session, addr_amt, ga::sdk::amount{ fee_rate }, send_all);
    })

GA_SDK_DEFINE_C_FUNCTION_1(GA_destroy_twofactor_call, struct GA_twofactor_call*, call, { delete call; });

namespace {
template <typename Obj> void c_invoke_convert_to_bool(const Obj* obj, const char* path, uint32_t* value)
{
    GA_SDK_RUNTIME_ASSERT(path);
    GA_SDK_RUNTIME_ASSERT(value);
    *value = obj->template get<bool>(path) == true ? 1 : 0;
}

template <typename Obj> void c_invoke_convert_to_string(const Obj* obj, const char* path, char** value)
{
    GA_SDK_RUNTIME_ASSERT(path);
    GA_SDK_RUNTIME_ASSERT(value);
    const auto v = obj->template get<std::string>(path);
    *value = to_c_string(v);
}

template <typename Obj> void c_invoke_convert_to_unsigned_integer(const Obj* obj, const char* path, size_t* value)
{
    GA_SDK_RUNTIME_ASSERT(path);
    GA_SDK_RUNTIME_ASSERT(value);
    *value = obj->template get<size_t>(path);
}
} // namespace

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_dict_path_to_bool, struct GA_dict*, dict, const char*, path, uint32_t*, value,
    { c_invoke_convert_to_bool(dict, path, value); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_dict_path_to_string, struct GA_dict*, dict, const char*, path, char**, value,
    { c_invoke_convert_to_string(dict, path, value); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_dict_path_to_unsigned_integer, struct GA_dict*, dict, const char*, path, size_t*,
    value, { c_invoke_convert_to_unsigned_integer(dict, path, value); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_tx_list_path_to_string, struct GA_tx_list*, txs, const char*, path, char**, value,
    { c_invoke_convert_to_string(txs, path, value); })
