#include <type_traits>

#include "include/amount.hpp"
#include "include/assertion.hpp"
#include "include/exception.hpp"
#include "include/session.h"
#include "include/session.hpp"
#include "include/twofactor.h"
#include "include/twofactor.hpp"

namespace {

void assert_invoke_args() {}

template <typename Arg, typename... Args>
typename std::enable_if_t<std::is_pointer<Arg>::value> assert_invoke_args(Arg arg, Args&&... args);

template <typename Arg, typename... Args>
typename std::enable_if_t<!std::is_pointer<Arg>::value> assert_invoke_args(
    Arg __attribute__((unused)) arg, Args&&... args)
{
    assert_invoke_args(std::forward<Args>(args)...);
}

template <typename Arg, typename... Args>
typename std::enable_if_t<std::is_pointer<Arg>::value> assert_invoke_args(Arg arg, Args&&... args)
{
    GA_SDK_RUNTIME_ASSERT(arg);
    assert_invoke_args(std::forward<Args>(args)...);
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

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_register_user, struct GA_session*, session, const char*, mnemonic, { session->register_user(mnemonic); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_login, struct GA_session*, session, const char*, mnemonic, { session->login(mnemonic); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_with_pin, struct GA_session*, session, const char*, pin, const GA_json*, pin_data,
    { session->login(pin, *json_cast(pin_data)); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_watch_only, struct GA_session*, session, const char*, username, const char*,
    password, { session->login_watch_only(username, password); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_fee_estimates, struct GA_session*, session, GA_json**, estimates,
    { *json_cast(estimates) = new nlohmann::json(session->get_fee_estimates()); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_get_mnemonic_passphrase, struct GA_session*, session, const char*, password, char**,
    mnemonic, { *mnemonic = to_c_string(session->get_mnemonic_passphrase(password ? password : std::string())); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_system_message, struct GA_session*, session, char**, message_text,
    { *message_text = to_c_string(session->get_system_message()); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_ack_system_message, struct GA_session*, session, const char*, message_text,
    { session->ack_system_message(message_text); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_twofactor_config, struct GA_session*, session, GA_json**, config,
    { *json_cast(config) = new nlohmann::json(session->get_twofactor_config()); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_create_transaction, struct GA_session*, session, const GA_json*, transaction_details,
    GA_json**, transaction,
    { *json_cast(transaction) = new nlohmann::json(session->create_transaction(*json_cast(transaction_details))); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_send_transaction, struct GA_session*, session, const GA_json*, transaction_details,
    const GA_json*, twofactor_data, GA_json**, transaction, {
        *json_cast(transaction)
            = new nlohmann::json(session->send(*json_cast(transaction_details), *json_cast(twofactor_data)));
    })

GA_SDK_DEFINE_C_FUNCTION_1(GA_send_nlocktimes, struct GA_session*, session, { session->send_nlocktimes(); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_set_transaction_memo, struct GA_session*, session, const char*, txhash_hex, const char*,
    memo, uint32_t, memo_type, {
        GA_SDK_RUNTIME_ASSERT(memo_type == GA_MEMO_USER || memo_type == GA_MEMO_BIP70);
        const std::string memo_type_str = memo_type == GA_MEMO_USER ? "user" : "payreq";
        session->set_transaction_memo(txhash_hex, memo, memo_type_str);
    })

using callback_t = void (*)(void*, char* output);

GA_SDK_DEFINE_C_FUNCTION_4(GA_subscribe_to_topic_as_json, struct GA_session*, session, const char*, topic, callback_t,
    callback, void*, context, {
        GA_SDK_RUNTIME_ASSERT(callback);
        session->subscribe(
            topic, [callback, context](const std::string& event) { callback(context, to_c_string(event)); });
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_remove_account, struct GA_session*, session, const GA_json*, twofactor_data,
    { session->remove_account(*json_cast(twofactor_data)); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_create_subaccount, struct GA_session*, session, const GA_json*, details, GA_json**,
    subaccount, { *json_cast(subaccount) = new nlohmann::json(session->create_subaccount(*json_cast(details))); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_subaccounts, struct GA_session*, session, GA_json**, subaccounts,
    { *json_cast(subaccounts) = new nlohmann::json(session->get_subaccounts()); })

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

GA_SDK_DEFINE_C_FUNCTION_4(GA_change_settings_tx_limits, struct GA_session*, session, uint32_t, is_fiat, uint32_t,
    total, const GA_json*, twofactor_data, {
        namespace sdk = ga::sdk;
        GA_SDK_RUNTIME_ASSERT(is_fiat == GA_FALSE || is_fiat == GA_TRUE);
        session->change_settings_tx_limits(is_fiat == GA_TRUE, total, *json_cast(twofactor_data));
    })

GA_SDK_DEFINE_C_FUNCTION_3(GA_change_settings_pricing_source, struct GA_session*, session, const char*, currency,
    const char*, exchange, { session->change_settings_pricing_source(currency, exchange); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_get_transactions, struct GA_session*, session, uint32_t, subaccount, uint32_t, page_id,
    GA_json**, txs, { *json_cast(txs) = new nlohmann::json(session->get_transactions(subaccount, page_id)); })

GA_SDK_DEFINE_C_FUNCTION_4(
    GA_get_receive_address, struct GA_session*, session, uint32_t, subaccount, uint32_t, addr_type, char**, output, {
        const auto r = session->get_receive_address(subaccount, static_cast<ga::sdk::address_type>(addr_type));
        *output = to_c_string(r["address"]);
    })

GA_SDK_DEFINE_C_FUNCTION_4(GA_get_balance, struct GA_session*, session, uint32_t, subaccount, uint32_t, num_confs,
    GA_json**, balance, { *json_cast(balance) = new nlohmann::json(session->get_balance(subaccount, num_confs)); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_get_unspent_outputs, struct GA_session*, session, uint32_t, subaccount, uint32_t,
    num_confs, GA_json**, utxos,
    { *json_cast(utxos) = new nlohmann::json(session->get_unspent_outputs(subaccount, num_confs)); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_get_transaction_details, struct GA_session*, session, const char*, txhash_hex, GA_json**,
    transaction, { *json_cast(transaction) = new nlohmann::json(session->get_transaction_details(txhash_hex)); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_available_currencies, struct GA_session*, session, GA_json**, available_currencies,
    { *json_cast(available_currencies) = new nlohmann::json(session->get_available_currencies()); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_amount, struct GA_session*, session, const GA_json*, json, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(session->convert_amount(*json_cast(json))); })

GA_SDK_DEFINE_C_FUNCTION_5(GA_set_pin, struct GA_session*, session, const char*, mnemonic, const char*, pin,
    const char*, device, GA_json**, pin_data,
    { *json_cast(pin_data) = new nlohmann::json(session->set_pin(mnemonic, pin, device)); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_string_to_json, const char*, input, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(nlohmann::json::parse(input)); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_json_to_string, const GA_json*, json, char**, output,
    { *output = to_c_string(json_cast(json)->dump()); });

// twofactor.h
//

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_get_methods, struct GA_twofactor_call*, call, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(call->get_twofactor_methods()); });

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_request_code, const char*, method, struct GA_twofactor_call*, call, { call->request_code(method); });

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_resolve_code, struct GA_twofactor_call*, call, const char*, code, { call->resolve_code(code); });

GA_SDK_DEFINE_C_FUNCTION_1(GA_twofactor_call, struct GA_twofactor_call*, call, { (*call)(); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_next_call, struct GA_twofactor_call*, call, struct GA_twofactor_call**, next,
    { *next = call->get_next_call(); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_get_result, struct GA_twofactor_call*, call, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(call->get_result()); });

GA_SDK_DEFINE_C_FUNCTION_1(GA_destroy_twofactor_call, struct GA_twofactor_call*, call, { delete call; });

GA_SDK_DEFINE_C_FUNCTION_3(GA_twofactor_set_email, struct GA_session*, session, const char*, email,
    struct GA_twofactor_call**, call, { *call = new GA_set_email_call(*session, email); });

GA_SDK_DEFINE_C_FUNCTION_4(GA_twofactor_enable, struct GA_session*, session, const char*, method, const char*, data,
    struct GA_twofactor_call**, call, {
        if (strcmp(method, "gauth") == 0) {
            // gauth is slightly different to the other methods and has its own
            // implementation
            *call = new GA_init_enable_gauth_call(*session);
        } else {
            GA_SDK_RUNTIME_ASSERT(data);
            *call = new GA_init_enable_twofactor(*session, method, data);
        }
    })

GA_SDK_DEFINE_C_FUNCTION_3(GA_twofactor_disable, struct GA_session*, session, const char*, method,
    struct GA_twofactor_call**, call, { *call = new GA_disable_twofactor(*session, method); });

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
