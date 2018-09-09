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

nlohmann::json* json_cast(GA_json* json) { return reinterpret_cast<nlohmann::json*>(json); }

const nlohmann::json* json_cast(const GA_json* json) { return reinterpret_cast<const nlohmann::json*>(json); }

nlohmann::json** json_cast(GA_json** json) { return reinterpret_cast<nlohmann::json**>(json); }

} // namespace

struct GA_session final : public ga::sdk::session {
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

#define GA_SDK_DEFINE_C_FUNCTION_9(NAME, T1, A1, T2, A2, T3, A3, T4, A4, T5, A5, T6, A6, T7, A7, T8, A8, T9, A9, BODY) \
    int NAME(T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7, T8 A8, T9 A9)                                            \
    {                                                                                                                  \
        return c_invoke([](T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7, T8 A8, T9 A9) BODY, A1, A2, A3, A4, A5,    \
            A6, A7, A8, A9);                                                                                           \
    }

#define GA_SDK_DEFINE_C_FUNCTION_10(                                                                                   \
    NAME, T1, A1, T2, A2, T3, A3, T4, A4, T5, A5, T6, A6, T7, A7, T8, A8, T9, A9, T10, A10, BODY)                      \
    int NAME(T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7, T8 A8, T9 A9, T10 A10)                                   \
    {                                                                                                                  \
        return c_invoke([](T1 A1, T2 A2, T3 A3, T4 A4, T5 A5, T6 A6, T7 A7, T8 A8, T9 A9, T10 A10) BODY, A1, A2, A3,   \
            A4, A5, A6, A7, A8, A9, A10);                                                                              \
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

int GA_destroy_json(GA_json* json)
{
    delete json_cast(json);
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

GA_SDK_DEFINE_C_FUNCTION_2(GA_login, struct GA_session*, session, const char*, mnemonic, {
    GA_SDK_RUNTIME_ASSERT(mnemonic);
    session->login(mnemonic);
})

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_with_pin, struct GA_session*, session, const char*, pin, const GA_json*, pin_data, {
    GA_SDK_RUNTIME_ASSERT(pin);
    GA_SDK_RUNTIME_ASSERT(pin_data);
    session->login(pin, *json_cast(pin_data));
})

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_login_watch_only, struct GA_session*, session, const char*, username, const char*, password, {
        GA_SDK_RUNTIME_ASSERT(username);
        GA_SDK_RUNTIME_ASSERT(password);
        session->login_watch_only(username, password);
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_fee_estimates, struct GA_session*, session, GA_json**, estimates, {
    GA_SDK_RUNTIME_ASSERT(estimates);
    *json_cast(estimates) = new nlohmann::json(session->get_fee_estimates());
})

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_get_mnemonic_passphrase, struct GA_session*, session, const char*, password, char**, mnemonic, {
        GA_SDK_RUNTIME_ASSERT(mnemonic);
        *mnemonic = to_c_string(session->get_mnemonic_passphrase(password ? password : std::string()));
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_system_message, struct GA_session*, session, char**, message_text, {
    GA_SDK_RUNTIME_ASSERT(message_text);
    *message_text = to_c_string(session->get_system_message());
})

GA_SDK_DEFINE_C_FUNCTION_2(GA_ack_system_message, struct GA_session*, session, const char*, message_text, {
    GA_SDK_RUNTIME_ASSERT(message_text);
    session->ack_system_message(message_text);
})

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_twofactor_config, struct GA_session*, session, GA_json**, config, {
    GA_SDK_RUNTIME_ASSERT(config);
    *json_cast(config) = new nlohmann::json(session->get_twofactor_config());
})

GA_SDK_DEFINE_C_FUNCTION_10(GA_send, struct GA_session*, session, uint32_t, subaccount, const char**, addr, size_t,
    addr_siz, const uint64_t*, amt, size_t, amt_siz, uint64_t, fee_rate, uint32_t, send_all, const GA_json*,
    twofactor_data, GA_json**, transaction, {
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
        const nlohmann::json empty;
        nlohmann::json tx_details;
        if (subaccount == GA_ALL_ACCOUNTS) {
            tx_details = session->send(addr_amt, ga::sdk::amount{ fee_rate }, send_all == GA_TRUE,
                twofactor_data ? *json_cast(twofactor_data) : empty);
        } else {
            tx_details = session->send(subaccount, addr_amt, ga::sdk::amount{ fee_rate }, send_all == GA_TRUE,
                twofactor_data ? *json_cast(twofactor_data) : empty);
        }
        *json_cast(transaction) = new nlohmann::json(tx_details);
    })

GA_SDK_DEFINE_C_FUNCTION_1(GA_send_nlocktimes, struct GA_session*, session, { session->send_nlocktimes(); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_set_transaction_memo, struct GA_session*, session, const char*, txhash_hex, const char*,
    memo, uint32_t, memo_type, {
        GA_SDK_RUNTIME_ASSERT(txhash_hex);
        GA_SDK_RUNTIME_ASSERT(memo);
        GA_SDK_RUNTIME_ASSERT(memo_type == GA_MEMO_USER || memo_type == GA_MEMO_BIP70);
        const std::string memo_type_str = memo_type == GA_MEMO_USER ? "user" : "payreq";
        session->set_transaction_memo(txhash_hex, memo, memo_type_str);
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

GA_SDK_DEFINE_C_FUNCTION_2(GA_remove_account, struct GA_session*, session, const GA_json*, twofactor_data,
    { session->remove_account(twofactor_data ? *json_cast(twofactor_data) : nlohmann::json()); })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_create_subaccount, struct GA_session*, session, const GA_json*, details, GA_json**, subaccount, {
        GA_SDK_RUNTIME_ASSERT(details);
        GA_SDK_RUNTIME_ASSERT(subaccount);
        *json_cast(subaccount) = new nlohmann::json(session->create_subaccount(*json_cast(details)));
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_subaccounts, struct GA_session*, session, GA_json**, subaccounts, {
    GA_SDK_RUNTIME_ASSERT(subaccounts);
    *json_cast(subaccounts) = new nlohmann::json(session->get_subaccounts());
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

GA_SDK_DEFINE_C_FUNCTION_5(GA_change_settings_tx_limits, struct GA_session*, session, uint32_t, is_fiat, uint32_t,
    per_tx, uint32_t, total, const GA_json*, twofactor_data, {
        namespace sdk = ga::sdk;
        GA_SDK_RUNTIME_ASSERT(is_fiat == GA_FALSE || is_fiat == GA_TRUE);
        session->change_settings_tx_limits(
            is_fiat == GA_TRUE, per_tx, total, twofactor_data ? *json_cast(twofactor_data) : nlohmann::json());
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_change_settings_pricing_source, struct GA_session*, session, const char*, currency, const char*, exchange, {
        GA_SDK_RUNTIME_ASSERT(currency);
        GA_SDK_RUNTIME_ASSERT(exchange);
        session->change_settings_pricing_source(currency, exchange);
    })

GA_SDK_DEFINE_C_FUNCTION_4(
    GA_get_transactions, struct GA_session*, session, uint32_t, subaccount, uint32_t, page_id, GA_json**, txs, {
        GA_SDK_RUNTIME_ASSERT(subaccount != GA_ALL_ACCOUNTS);
        *json_cast(txs) = new nlohmann::json(session->get_transactions(subaccount, page_id));
    })

GA_SDK_DEFINE_C_FUNCTION_4(
    GA_get_receive_address, struct GA_session*, session, uint32_t, subaccount, uint32_t, addr_type, char**, output, {
        namespace sdk = ga::sdk;
        GA_SDK_RUNTIME_ASSERT(output);
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
        *output = to_c_string(r["address"]);
    })

GA_SDK_DEFINE_C_FUNCTION_4(
    GA_get_balance, struct GA_session*, session, uint32_t, subaccount, uint32_t, num_confs, GA_json**, balance, {
        GA_SDK_RUNTIME_ASSERT(balance);
        if (subaccount == GA_ALL_ACCOUNTS) {
            *json_cast(balance) = new nlohmann::json(session->get_balance(num_confs));
        } else {
            *json_cast(balance) = new nlohmann::json(session->get_balance(subaccount, num_confs));
        }
    })

GA_SDK_DEFINE_C_FUNCTION_4(
    GA_get_unspent_outputs, struct GA_session*, session, uint32_t, subaccount, uint32_t, num_confs, GA_json**, utxos, {
        GA_SDK_RUNTIME_ASSERT(subaccount != GA_ALL_ACCOUNTS); // FIXME: Not yet supported
        GA_SDK_RUNTIME_ASSERT(utxos);
        *json_cast(utxos) = new nlohmann::json(session->get_unspent_outputs(subaccount, num_confs));
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_get_transaction_details, struct GA_session*, session, const char*, txhash_hex, GA_json**, transaction, {
        GA_SDK_RUNTIME_ASSERT(txhash_hex);
        GA_SDK_RUNTIME_ASSERT(transaction);
        *json_cast(transaction) = new nlohmann::json(session->get_transaction_details(txhash_hex));
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_available_currencies, struct GA_session*, session, GA_json**, available_currencies, {
    GA_SDK_RUNTIME_ASSERT(available_currencies);
    *json_cast(available_currencies) = new nlohmann::json(session->get_available_currencies());
})

GA_SDK_DEFINE_C_FUNCTION_5(GA_set_pin, struct GA_session*, session, const char*, mnemonic, const char*, pin,
    const char*, device, GA_json**, pin_data, {
        GA_SDK_RUNTIME_ASSERT(mnemonic);
        GA_SDK_RUNTIME_ASSERT(pin);
        GA_SDK_RUNTIME_ASSERT(device);
        GA_SDK_RUNTIME_ASSERT(pin_data);
        *json_cast(pin_data) = new nlohmann::json(session->set_pin(mnemonic, pin, device));
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_string_to_json, const char*, input, GA_json**, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    *json_cast(output) = new nlohmann::json(nlohmann::json::parse(input));
});

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_json_to_string, const GA_json*, json, char**, output, {
    GA_SDK_RUNTIME_ASSERT(output);
    *output = to_c_string(json_cast(json)->dump());
});

// twofactor.h
//

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_factor_list_get_size, struct GA_twofactor_factor_list*, factors, uint32_t*, output, {
        GA_SDK_RUNTIME_ASSERT(output);
        *output = factors->size();
    });

GA_SDK_DEFINE_C_FUNCTION_3(GA_twofactor_factor_list_get_factor, struct GA_twofactor_factor_list*, factors, uint32_t, i,
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

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_factor_type, const struct GA_twofactor_factor*, factor, char**, type, {
    GA_SDK_RUNTIME_ASSERT(type);
    *type = to_c_string(factor->get_type());
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

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_next_call, struct GA_twofactor_call*, call, struct GA_twofactor_call**, next, {
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

GA_SDK_DEFINE_C_FUNCTION_8(GA_twofactor_send, struct GA_session*, session, const char**, addr, uint32_t, addr_siz,
    const uint64_t*, amt, uint32_t, amt_siz, uint64_t, fee_rate, uint32_t, send_all, struct GA_twofactor_call**, call, {
        GA_SDK_RUNTIME_ASSERT(session);
        GA_SDK_RUNTIME_ASSERT(addr);
        GA_SDK_RUNTIME_ASSERT(amt);
        GA_SDK_RUNTIME_ASSERT(addr_siz == amt_siz);
        std::vector<ga::sdk::session::address_amount_pair> addr_amt;
        addr_amt.reserve(addr_siz);
        for (uint32_t i = 0; i < addr_siz; ++i) {
            GA_SDK_RUNTIME_ASSERT(addr[i]);
            addr_amt.emplace_back(std::make_pair(addr[i], ga::sdk::amount{ amt[i] }));
        }
        *call = new GA_send_call(*session, addr_amt, ga::sdk::amount{ fee_rate }, send_all);
    })

GA_SDK_DEFINE_C_FUNCTION_1(GA_destroy_twofactor_call, struct GA_twofactor_call*, call, { delete call; });

namespace {
template <typename T> void json_convert(const nlohmann::json& json, const char* path, T* value)
{
    GA_SDK_RUNTIME_ASSERT(path);
    GA_SDK_RUNTIME_ASSERT(value);
    const auto v = json[path];
    if (v.is_null()) {
        *value = T();
    } else {
        *value = v;
    }
}

} // namespace

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_json_value_to_bool, const GA_json*, json, const char*, path, uint32_t*, output, {
    bool v;
    json_convert(*json_cast(json), path, &v);
    *output = v ? GA_TRUE : GA_FALSE;
})

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_json_value_to_string, const GA_json*, json, const char*, path, char**, output, {
    std::string v;
    json_convert(*json_cast(json), path, &v);
    *output = to_c_string(v);
})

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_json_value_to_uint32, const GA_json*, json, const char*, path, uint32_t*, output,
    { json_convert(*json_cast(json), path, output); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_json_value_to_uint64, const GA_json*, json, const char*, path, uint64_t*, output,
    { json_convert(*json_cast(json), path, output); })
