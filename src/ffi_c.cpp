#include "amount.hpp"
#include "assertion.hpp"
#include "common.h"
#include "exception.hpp"
#include "session.h"
#include "session.hpp"

namespace {
template <typename F, typename Obj, typename... Args> auto c_invoke(F&& f, Obj* obj, Args&&... args)
{
    try {
        GA_SDK_RUNTIME_ASSERT(obj);
        f(obj, std::forward<Args>(args)...);
        return GA_OK;
    } catch (const autobahn::no_session_error& e) {
        return GA_SESSION_LOST;
    } catch (const ga::sdk::reconnect_error& ex) {
        return GA_RECONNECT;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
}

char* to_c_string(const std::string& s)
{
    char* str = new char[s.size() + 1];
    std::copy(s.begin(), s.end(), str);
    *(str + s.size()) = 0;
    return str;
}
}

struct GA_session final : public ga::sdk::session {
};

struct GA_dict final : public ga::sdk::detail::object_container<GA_dict> {
};

struct GA_tx final : public ga::sdk::tx {
    GA_tx& operator=(const msgpack_object& data)
    {
        ga::sdk::tx::operator=(data);
        return *this;
    }
};

struct GA_tx_list final : public ga::sdk::tx_list {
    GA_tx_list& operator=(const msgpack_object& data)
    {
        ga::sdk::tx_list::operator=(data);
        return *this;
    }
};

struct GA_balance final : public ga::sdk::balance {
    GA_balance& operator=(const msgpack_object& data)
    {
        ga::sdk::balance::operator=(data);
        return *this;
    }
};

struct GA_available_currencies final : public ga::sdk::available_currencies {
    GA_available_currencies& operator=(const msgpack_object& data)
    {
        ga::sdk::available_currencies::operator=(data);
        return *this;
    }
};

struct GA_login_data final : public ga::sdk::login_data {
    GA_login_data& operator=(const msgpack_object& data)
    {
        ga::sdk::login_data::operator=(data);
        return *this;
    }
};

#define GA_SDK_DEFINE_C_FUNCTION_0(c_function_name, c_obj_name, c_function_body)                                       \
    int c_function_name(struct c_obj_name* obj) { return c_invoke(c_function_body, obj); }

#define GA_SDK_DEFINE_C_FUNCTION_1(c_function_name, c_obj_name, c_function_body, T1, ARG1)                             \
    int c_function_name(struct c_obj_name* obj, T1 ARG1) { return c_invoke(c_function_body, obj, ARG1); }

#define GA_SDK_DEFINE_C_FUNCTION_2(c_function_name, c_obj_name, c_function_body, T1, ARG1, T2, ARG2)                   \
    int c_function_name(struct c_obj_name* obj, T1 ARG1, T2 ARG2) { return c_invoke(c_function_body, obj, ARG1, ARG2); }

#define GA_SDK_DEFINE_C_FUNCTION_3(c_function_name, c_obj_name, c_function_body, T1, ARG1, T2, ARG2, T3, ARG3)         \
    int c_function_name(struct c_obj_name* obj, T1 ARG1, T2 ARG2, T3 ARG3)                                             \
    {                                                                                                                  \
        return c_invoke(c_function_body, obj, ARG1, ARG2, ARG3);                                                       \
    }

#define GA_SDK_DEFINE_C_FUNCTION_4(                                                                                    \
    c_function_name, c_obj_name, c_function_body, T1, ARG1, T2, ARG2, T3, ARG3, T4, ARG4)                              \
    int c_function_name(struct c_obj_name* obj, T1 ARG1, T2 ARG2, T3 ARG3, T4 ARG4)                                    \
    {                                                                                                                  \
        return c_invoke(c_function_body, obj, ARG1, ARG2, ARG3, ARG4);                                                 \
    }

#define GA_SDK_DEFINE_C_FUNCTION_6(                                                                                    \
    c_function_name, c_obj_name, c_function_body, T1, ARG1, T2, ARG2, T3, ARG3, T4, ARG4, T5, ARG5, T6, ARG6)          \
    int c_function_name(struct c_obj_name* obj, T1 ARG1, T2 ARG2, T3 ARG3, T4 ARG4, T5 ARG5, T6 ARG6)                  \
    {                                                                                                                  \
        return c_invoke(c_function_body, obj, ARG1, ARG2, ARG3, ARG4, ARG5, ARG6);                                     \
    }

#define GA_SDK_DEFINE_C_FUNCTION_7(c_function_name, c_obj_name, c_function_body, T1, ARG1, T2, ARG2, T3, ARG3, T4,     \
                                   ARG4, T5, ARG5, T6, ARG6, T7, ARG7)                                                 \
    int c_function_name(struct c_obj_name* obj, T1 ARG1, T2 ARG2, T3 ARG3, T4 ARG4, T5 ARG5, T6 ARG6, T7 ARG7)         \
    {                                                                                                                  \
        return c_invoke(c_function_body, obj, ARG1, ARG2, ARG3, ARG4, ARG5, ARG6, ARG7);                               \
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

GA_SDK_DEFINE_C_FUNCTION_2(GA_connect, GA_session,
    [](struct GA_session* session, int network, int debug) {
        auto&& params = network == GA_NETWORK_REGTEST ? ga::sdk::make_regtest_network()
                                                      : network == GA_NETWORK_LOCALTEST
                ? ga::sdk::make_localtest_network()
                : network == GA_NETWORK_TESTNET ? ga::sdk::make_testnet_network() : ga::sdk::make_localtest_network();
        session->connect(std::move(params), debug != 0);
    },
    int, network, int, debug)

GA_SDK_DEFINE_C_FUNCTION_0(GA_disconnect, GA_session, [](struct GA_session* session) { session->disconnect(); })

GA_SDK_DEFINE_C_FUNCTION_1(GA_register_user, GA_session,
    [](struct GA_session* session, const char* mnemonic) { session->register_user(mnemonic); }, const char*, mnemonic)

GA_SDK_DEFINE_C_FUNCTION_2(GA_login, GA_session,
    [](struct GA_session* session, const char* mnemonic, struct GA_login_data** login_data) {
        GA_SDK_RUNTIME_ASSERT(login_data);
        const auto result = session->login(mnemonic);
        *login_data = new GA_login_data;
        **login_data = result.get_handle().get();
    },
    const char*, mnemonic, struct GA_login_data**, login_data);

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_with_pin, GA_session,
    [](struct GA_session* session, const char* pin, const char* pin_identifier_and_secret,
        struct GA_login_data** login_data) {
        GA_SDK_RUNTIME_ASSERT(pin);
        GA_SDK_RUNTIME_ASSERT(pin_identifier_and_secret);
        GA_SDK_RUNTIME_ASSERT(login_data);
        const auto s = std::string(pin_identifier_and_secret);
        const auto pos = s.find(':');
        GA_SDK_RUNTIME_ASSERT(pos != std::string::npos);
        const auto result = session->login(
            pin, std::make_pair(std::string(s.begin(), s.begin() + pos), std::string(s.begin() + pos, s.end())));
        *login_data = new GA_login_data;
        **login_data = result.get_handle().get();
    },
    const char*, pin, const char*, pin_identifier_and_secret, struct GA_login_data**, login_data);

GA_SDK_DEFINE_C_FUNCTION_6(GA_send, GA_session,
    [](struct GA_session* session, const char** addr, size_t addr_siz, const uint64_t* amt, size_t amt_siz,
        uint64_t fee_rate, bool send_all) {
        GA_SDK_RUNTIME_ASSERT(addr);
        GA_SDK_RUNTIME_ASSERT(amt);
        GA_SDK_RUNTIME_ASSERT(addr_siz == amt_siz);
        std::vector<ga::sdk::session::address_amount_pair> addr_amt;
        addr_amt.reserve(addr_siz);
        for (size_t i = 0; i < addr_siz; ++i) {
            GA_SDK_RUNTIME_ASSERT(addr[i]);
            addr_amt.emplace_back(std::make_pair(addr[i], amt[i]));
        }
        session->send(addr_amt, fee_rate, send_all);
    },
    const char**, addr, size_t, addr_siz, const uint64_t*, amt, size_t, amt_siz, uint64_t, fee_rate, bool, send_all);

using callback_t = void (*)(void*, char* output);

GA_SDK_DEFINE_C_FUNCTION_3(GA_subscribe_to_topic_as_json, GA_session,
    [](struct GA_session* session, const char* topic, callback_t callback, void* context) {
        GA_SDK_RUNTIME_ASSERT(topic);
        GA_SDK_RUNTIME_ASSERT(callback);
        GA_SDK_RUNTIME_ASSERT(context);
        session->subscribe(
            topic, [callback, context](const std::string& event) { callback(context, to_c_string(event)); });
    },
    const char*, topic, callback_t, callback, void*, context);

GA_SDK_DEFINE_C_FUNCTION_3(GA_login_watch_only, GA_session,
    [](struct GA_session* session, const char* username, const char* password, struct GA_login_data** login_data) {
        GA_SDK_RUNTIME_ASSERT(username);
        GA_SDK_RUNTIME_ASSERT(password);
        GA_SDK_RUNTIME_ASSERT(login_data);
        const auto result = session->login_watch_only(username, password);
        *login_data = new GA_login_data;
        **login_data = result.get_handle().get();
    },
    const char*, username, const char*, password, struct GA_login_data**, login_data);

GA_SDK_DEFINE_C_FUNCTION_0(GA_remove_account, GA_session, [](struct GA_session* session) { session->remove_account(); })

GA_SDK_DEFINE_C_FUNCTION_1(GA_change_settings_privacy_send_me, GA_session,
    [](struct GA_session* session, int param) {
        namespace sdk = ga::sdk;
        session->change_settings(sdk::settings::privacy_send_me, sdk::privacy_send_me(param));
    },
    int, param);

GA_SDK_DEFINE_C_FUNCTION_1(GA_change_settings_privacy_show_as_sender, GA_session,
    [](struct GA_session* session, int param) {
        namespace sdk = ga::sdk;
        session->change_settings(sdk::settings::privacy_show_as_sender, sdk::privacy_show_as_sender(param));
    },
    int, param);

GA_SDK_DEFINE_C_FUNCTION_3(GA_change_settings_tx_limits, GA_session,
    [](struct GA_session* session, int is_fiat, int per_tx, int total) {
        namespace sdk = ga::sdk;
        session->change_settings(sdk::settings::tx_limits, sdk::tx_limits::is_fiat, is_fiat, sdk::tx_limits::per_tx,
            per_tx, sdk::tx_limits::total, total);
    },
    int, is_fiat, int, per_tx, int, total);

GA_SDK_DEFINE_C_FUNCTION_7(GA_get_tx_list, GA_session,
    [](struct GA_session* session, time_t begin_date, time_t end_date, size_t subaccount, int sort_by, size_t page_id,
        const char* query, struct GA_tx_list** txs) {
        using namespace ga::sdk::literals;
        namespace sdk = ga::sdk;
        sdk::tx_list_sort_by sort_by_lit = sort_by == GA_TIMESTAMP
            ? ' '_ts
            : sort_by == GA_TIMESTAMP_ASCENDING ? '+'_ts
                                                : sort_by == GA_TIMESTAMP_DESCENDING ? '-'_ts
                                                                                     : sort_by == GA_VALUE
                        ? ' '_value
                        : sort_by == GA_VALUE_ASCENDING ? '+'_value
                                                        : sort_by == GA_VALUE_DESCENDING ? '-'_value : ' '_ts;
        const auto result
            = session->get_tx_list(std::make_pair(begin_date, end_date), subaccount, sort_by_lit, page_id, query);
        GA_SDK_RUNTIME_ASSERT(txs);
        *txs = new GA_tx_list;
        GA_SDK_RUNTIME_ASSERT(*txs);
        **txs = result.get_handle().get();
    },
    time_t, begin_date, time_t, end_date, size_t, subaccount, int, sort_by, size_t, page_id, const char*, query,
    struct GA_tx_list**, txs);

GA_SDK_DEFINE_C_FUNCTION_3(GA_get_receive_address, GA_session,
    [](struct GA_session* session, int addr_type, size_t subaccount, char** address) {
        namespace sdk = ga::sdk;
        GA_SDK_RUNTIME_ASSERT(address);
        sdk::address_type t = addr_type == GA_ADDRESS_TYPE_P2SH ? sdk::address_type::p2sh : sdk::address_type::p2wsh;
        const auto r = session->get_receive_address(t, subaccount);
        const auto a = r.get_address();
        *address = to_c_string(a);
    },
    int, addr_type, size_t, subaccount, char**, address);

GA_SDK_DEFINE_C_FUNCTION_3(GA_get_balance_for_subaccount, GA_session,
    [](struct GA_session* session, size_t subaccount, size_t num_confs, struct GA_balance** balance) {
        GA_SDK_RUNTIME_ASSERT(balance);
        const auto result = session->get_balance_for_subaccount(subaccount, num_confs);
        *balance = new GA_balance;
        **balance = result.get_handle().get();
    },
    size_t, subaccount, size_t, num_confs, struct GA_balance**, balance);

GA_SDK_DEFINE_C_FUNCTION_2(GA_get_balance, GA_session,
    [](struct GA_session* session, size_t num_confs, struct GA_balance** balance) {
        GA_SDK_RUNTIME_ASSERT(balance);
        const auto result = session->get_balance(num_confs);
        *balance = new GA_balance;
        **balance = result.get_handle().get();
    },
    size_t, num_confs, struct GA_balance**, balance);

GA_SDK_DEFINE_C_FUNCTION_1(GA_get_available_currencies, GA_session,
    [](struct GA_session* session, struct GA_available_currencies** available_currencies) {
        GA_SDK_RUNTIME_ASSERT(available_currencies);
        const auto result = session->get_available_currencies();
        *available_currencies = new GA_available_currencies;
        **available_currencies = result.get_handle().get();
    },
    struct GA_available_currencies**, available_currencies);

GA_SDK_DEFINE_C_FUNCTION_4(GA_set_pin, GA_session,
    [](struct GA_session* session, const char* mnemonic, const char* pin, const char* device,
        char** pin_identifier_and_secret) {
        GA_SDK_RUNTIME_ASSERT(pin_identifier_and_secret);
        const auto p = session->set_pin(mnemonic, pin, device);
        *pin_identifier_and_secret = to_c_string(p.at("pin_identifier") + ':' + p.at("secret"));
    },
    const char*, mnemonic, const char*, pin, const char*, device, char**, pin_identifier_and_secret);

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_tx_list_path_to_dict, GA_tx_list,
    [](struct GA_tx_list* txs, const char* path, struct GA_dict** value) {
        GA_SDK_RUNTIME_ASSERT(path);
        GA_SDK_RUNTIME_ASSERT(value);
        const auto v = txs->get<msgpack::object>(path);
        *value = new struct GA_dict();
        (*value)->associate(v);
    },
    const char*, path, struct GA_dict**, value);

GA_SDK_DEFINE_C_FUNCTION_1(GA_convert_tx_list_to_json, GA_tx_list,
    [](struct GA_tx_list* txs, char** output) {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto v = txs->get_json();
        *output = to_c_string(v);
    },
    char**, output);

GA_SDK_DEFINE_C_FUNCTION_1(GA_tx_list_get_size, GA_tx_list,
    [](struct GA_tx_list* txs, size_t* output) {
        GA_SDK_RUNTIME_ASSERT(output);
        *output = txs->size();
    },
    size_t*, output);

GA_SDK_DEFINE_C_FUNCTION_2(GA_tx_list_get_tx, GA_tx_list,
    [](struct GA_tx_list* txs, size_t i, struct GA_tx** output) {
        GA_SDK_RUNTIME_ASSERT(output);
        GA_SDK_RUNTIME_ASSERT(i < txs->size());
        *output = new GA_tx;
        **output = *(txs->begin() + i);
    },
    size_t, i, struct GA_tx**, output);

GA_SDK_DEFINE_C_FUNCTION_1(GA_transaction_to_json, GA_tx,
    [](struct GA_tx* tx, char** output) {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto v = tx->get_json();
        *output = to_c_string(v);
    },
    char**, output);

GA_SDK_DEFINE_C_FUNCTION_1(GA_convert_balance_to_json, GA_balance,
    [](struct GA_balance* balance, char** output) {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto v = balance->get_json();
        *output = to_c_string(v);
    },
    char**, output);

GA_SDK_DEFINE_C_FUNCTION_1(GA_convert_available_currencies_to_json, GA_available_currencies,
    [](struct GA_available_currencies* currencies, char** output) {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto v = currencies->get_json();
        *output = to_c_string(v);
    },
    char**, output);

GA_SDK_DEFINE_C_FUNCTION_1(GA_convert_login_data_to_json, GA_login_data,
    [](struct GA_login_data* login_data, char** output) {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto v = login_data->get_json();
        *output = to_c_string(v);
    },
    char**, output);

namespace {
template <typename Obj> void c_invoke_convert_to_bool(const Obj* obj, const char* path, int* value)
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
}

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_dict_path_to_bool, GA_dict,
    [](struct GA_dict* dict, const char* path, int* value) { c_invoke_convert_to_bool(dict, path, value); },
    const char*, path, int*, value);

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_dict_path_to_string, GA_dict,
    [](struct GA_dict* dict, const char* path, char** value) { c_invoke_convert_to_string(dict, path, value); },
    const char*, path, char**, value);

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_dict_path_to_unsigned_integer, GA_dict,
    [](struct GA_dict* dict, const char* path, size_t* value) {
        c_invoke_convert_to_unsigned_integer(dict, path, value);
    },
    const char*, path, size_t*, value);

GA_SDK_DEFINE_C_FUNCTION_2(GA_convert_tx_list_path_to_string, GA_tx_list,
    [](struct GA_tx_list* txs, const char* path, char** value) { c_invoke_convert_to_string(txs, path, value); },
    const char*, path, char**, value);
