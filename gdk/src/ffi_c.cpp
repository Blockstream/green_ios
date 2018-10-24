#include <initializer_list>
#include <type_traits>

#include "exception.hpp"
#include "include/amount.hpp"
#include "include/network_parameters.hpp"
#include "include/session.h"
#include "include/session.hpp"
#include "include/twofactor.h"
#include "include/twofactor.hpp"
#include "include/utils.h"
#include "src/twofactor_calls.hpp"

namespace {

template <typename Arg>
static typename std::enable_if_t<!std::is_pointer<Arg>::value> assert_pointer_args(
    const Arg& arg __attribute__((unused)))
{
}

template <typename Arg>
static typename std::enable_if_t<std::is_pointer<Arg>::value> assert_pointer_args(const Arg& arg)
{
    GA_SDK_RUNTIME_ASSERT(arg);
}

template <typename... Args> static void assert_invoke_args(Args&&... args)
{
    (void)std::initializer_list<int>{ (assert_pointer_args(std::forward<Args>(args)), 0)... };
}

template <typename F, typename... Args> static auto c_invoke(F&& f, Args&&... args)
{
    try {
        assert_invoke_args(std::forward<Args>(args)...);
        f(std::forward<Args>(args)...);
        return GA_OK;
    } catch (const ga::sdk::login_error& e) {
        return GA_ERROR;
    } catch (const autobahn::no_session_error& e) {
        return GA_SESSION_LOST;
    } catch (const ga::sdk::reconnect_error& e) {
        return GA_RECONNECT;
    } catch (const ga::sdk::timeout_error& e) {
        return GA_TIMEOUT;
    } catch (const std::exception& e) {
        return GA_ERROR;
    }
}

static char* to_c_string(const std::string& s)
{
    auto* str = new char[s.size() + 1];
    std::copy(s.begin(), s.end(), str);
    *(str + s.size()) = 0;
    return str;
}

static nlohmann::json* json_cast(GA_json* json) { return reinterpret_cast<nlohmann::json*>(json); }

static const nlohmann::json* json_cast(const GA_json* json) { return reinterpret_cast<const nlohmann::json*>(json); }

static nlohmann::json** json_cast(GA_json** json) { return reinterpret_cast<nlohmann::json**>(json); }

template <typename T> static void json_convert(const nlohmann::json& json, const char* path, T* value)
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
    } catch (const std::exception& e) {
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

GA_SDK_DEFINE_C_FUNCTION_3(GA_connect, struct GA_session*, session, const char*, network, uint32_t, debug,
    { return GA_connect_with_proxy(session, network, "", GA_NO_TOR, debug); })

GA_SDK_DEFINE_C_FUNCTION_5(GA_connect_with_proxy, struct GA_session*, session, const char*, network, const char*,
    proxy_uri, uint32_t, use_tor, uint32_t, debug,
    { session->connect(network, proxy_uri, use_tor != GA_FALSE, debug != GA_FALSE); })

GA_SDK_DEFINE_C_FUNCTION_1(GA_disconnect, struct GA_session*, session, { session->disconnect(); })

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_register_user, struct GA_session*, session, const char*, mnemonic, { session->register_user(mnemonic); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_register_user_with_hardware, struct GA_session*, session, const GA_json*, device_data,
    struct GA_twofactor_call**, call, { *call = new GA_register_call(*session, *json_cast(device_data)); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_login, struct GA_session*, session, const char*, mnemonic, const char*, password,
    { session->login(mnemonic, password); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_with_pin, struct GA_session*, session, const char*, pin, const GA_json*, pin_data,
    { session->login_with_pin(pin, *json_cast(pin_data)); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_with_hardware, struct GA_session*, session, const GA_json*, device_data,
    struct GA_twofactor_call**, call, { *call = new GA_login_call(*session, *json_cast(device_data)); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_watch_only, struct GA_session*, session, const char*, username, const char*,
    password, { session->login_watch_only(username, password); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_set_watch_only, struct GA_session*, session, const char*, username, const char*, password,
    { session->set_watch_only(username, password); })

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

GA_SDK_DEFINE_C_FUNCTION_3(GA_sign_transaction, struct GA_session*, session, const GA_json*, transaction_details,
    GA_json**, transaction,
    { *json_cast(transaction) = new nlohmann::json(session->sign_transaction(*json_cast(transaction_details))); })

GA_SDK_DEFINE_C_FUNCTION_1(GA_send_nlocktimes, struct GA_session*, session, { session->send_nlocktimes(); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_set_transaction_memo, struct GA_session*, session, const char*, txhash_hex, const char*,
    memo, uint32_t, memo_type, {
        GA_SDK_RUNTIME_ASSERT(memo_type == GA_MEMO_USER || memo_type == GA_MEMO_BIP70);
        const std::string memo_type_str = memo_type == GA_MEMO_USER ? "user" : "payreq";
        session->set_transaction_memo(txhash_hex, memo, memo_type_str);
    })

GA_SDK_DEFINE_C_FUNCTION_3(
    GA_set_notification_handler, struct GA_session*, session, GA_notification_handler, handler, void*, context, {
        GA_SDK_RUNTIME_ASSERT(handler);
        session->set_notification_handler(handler, context);
    })

GA_SDK_DEFINE_C_FUNCTION_2(GA_remove_account, struct GA_session*, session, struct GA_twofactor_call**, call,
    { *call = new GA_remove_account_call(*session); });

GA_SDK_DEFINE_C_FUNCTION_3(GA_create_subaccount, struct GA_session*, session, const GA_json*, details, GA_json**,
    subaccount, { *json_cast(subaccount) = new nlohmann::json(session->create_subaccount(*json_cast(details))); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_subaccounts, struct GA_session*, session, GA_json**, subaccounts,
    { *json_cast(subaccounts) = new nlohmann::json(session->get_subaccounts()); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_change_settings_pricing_source, struct GA_session*, session, const char*, currency,
    const char*, exchange, { session->change_settings_pricing_source(currency, exchange); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_get_transactions, struct GA_session*, session, uint32_t, subaccount, uint32_t, page_id,
    GA_json**, txs, { *json_cast(txs) = new nlohmann::json(session->get_transactions(subaccount, page_id)); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_get_receive_address, struct GA_session*, session, uint32_t, subaccount, char**, output,
    { *output = to_c_string(session->get_receive_address(subaccount)["address"]); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_get_balance, struct GA_session*, session, uint32_t, subaccount, uint32_t, num_confs,
    GA_json**, balance, { *json_cast(balance) = new nlohmann::json(session->get_balance(subaccount, num_confs)); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_get_unspent_outputs, struct GA_session*, session, uint32_t, subaccount, uint32_t,
    num_confs, GA_json**, utxos,
    { *json_cast(utxos) = new nlohmann::json(session->get_unspent_outputs(subaccount, num_confs)); })

GA_SDK_DEFINE_C_FUNCTION_5(GA_get_unspent_outputs_for_private_key, struct GA_session*, session, const char*,
    private_key, const char*, password, uint32_t, unused, GA_json**, utxos, {
        *json_cast(utxos)
            = new nlohmann::json(session->get_unspent_outputs_for_private_key(private_key, password, unused));
    })

GA_SDK_DEFINE_C_FUNCTION_3(GA_get_transaction_details, struct GA_session*, session, const char*, txhash_hex, GA_json**,
    transaction, { *json_cast(transaction) = new nlohmann::json(session->get_transaction_details(txhash_hex)); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_available_currencies, struct GA_session*, session, GA_json**, available_currencies,
    { *json_cast(available_currencies) = new nlohmann::json(session->get_available_currencies()); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_convert_amount, struct GA_session*, session, const GA_json*, json, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(session->convert_amount(*json_cast(json))); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_encrypt, struct GA_session*, session, const GA_json*, input, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(session->encrypt(*json_cast(input))); })

GA_SDK_DEFINE_C_FUNCTION_3(GA_decrypt, struct GA_session*, session, const GA_json*, input, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(session->decrypt(*json_cast(input))); })

GA_SDK_DEFINE_C_FUNCTION_5(GA_set_pin, struct GA_session*, session, const char*, mnemonic, const char*, pin,
    const char*, device, GA_json**, pin_data,
    { *json_cast(pin_data) = new nlohmann::json(session->set_pin(mnemonic, pin, device)); })

GA_SDK_DEFINE_C_FUNCTION_2(GA_set_current_subaccount, struct GA_session*, session, uint32_t, subaccount,
    { session->set_current_subaccount(subaccount); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_string_to_json, const char*, input, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(nlohmann::json::parse(input)); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_json_to_string, const GA_json*, json, char**, output,
    { *output = to_c_string(json_cast(json)->dump()); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_register_network, const char*, name, const GA_json*, json,
    { ga::sdk::network_parameters::add(name, *json_cast(json)); });

GA_SDK_DEFINE_C_FUNCTION_1(GA_get_networks, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(ga::sdk::network_parameters::get_all()); });

// twofactor.h
//

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_request_code, struct GA_twofactor_call*, call, const char*, method, { call->request_code(method); });

GA_SDK_DEFINE_C_FUNCTION_2(
    GA_twofactor_resolve_code, struct GA_twofactor_call*, call, const char*, code, { call->resolve_code(code); });

GA_SDK_DEFINE_C_FUNCTION_1(GA_twofactor_call, struct GA_twofactor_call*, call, { (*call)(); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_get_status, struct GA_twofactor_call*, call, GA_json**, output,
    { *json_cast(output) = new nlohmann::json(call->get_status()); });

GA_SDK_DEFINE_C_FUNCTION_1(GA_destroy_twofactor_call, struct GA_twofactor_call*, call, { delete call; });

GA_SDK_DEFINE_C_FUNCTION_4(GA_change_settings_twofactor, struct GA_session*, session, const char*, method,
    const GA_json*, details, struct GA_twofactor_call**, call,
    { *call = new GA_change_settings_twofactor_call(*session, method, *json_cast(details)); })

GA_SDK_DEFINE_C_FUNCTION_4(GA_twofactor_reset, struct GA_session*, session, const char*, email, uint32_t, is_dispute,
    struct GA_twofactor_call**, call,
    { *call = new GA_twofactor_reset_call(*session, email, is_dispute != GA_FALSE); });

GA_SDK_DEFINE_C_FUNCTION_2(GA_twofactor_cancel_reset, struct GA_session*, session, struct GA_twofactor_call**, call,
    { *call = new GA_twofactor_cancel_reset_call(*session); });

GA_SDK_DEFINE_C_FUNCTION_3(GA_send_transaction, struct GA_session*, session, const GA_json*, transaction_details,
    struct GA_twofactor_call**, call, { *call = new GA_send_call(*session, *json_cast(transaction_details)); });

GA_SDK_DEFINE_C_FUNCTION_3(GA_twofactor_change_limits, struct GA_session*, session, const GA_json*, details,
    struct GA_twofactor_call**, call, { *call = new GA_change_limits_call(*session, *json_cast(details)); })

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
