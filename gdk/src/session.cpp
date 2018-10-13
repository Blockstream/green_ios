#include <string>
#include <vector>

#include "include/session.hpp"

#include "autobahn_wrapper.hpp"
#include "exception.hpp"
#include "ga_session.hpp"
#include "logging.hpp"

namespace ga {
namespace sdk {
    namespace address_type {
        const std::string p2sh("p2sh");
        const std::string p2wsh("p2wsh");
        const std::string csv("csv");
    }; // namespace address_type

    template <typename F, typename... Args> auto session::exception_wrapper(F&& f, Args&&... args)
    {
        try {
            return f(std::forward<Args>(args)...);
        } catch (const autobahn::abort_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const login_error& e) {
            throw;
        } catch (const autobahn::network_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const autobahn::no_transport_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const autobahn::protocol_error& e) {
            disconnect();
            throw reconnect_error();
        } catch (const autobahn::call_error& e) {
            try {
                std::pair<std::string, std::string> details = get_error_details(e);
                GDK_LOG_SEV(log_level::debug) << "server exception (" << details.first << "):" << details.second;
            } catch (const std::exception&) {
            }
            throw;
        } catch (const std::exception& e) {
            try {
                const auto what = e.what();
                GDK_LOG_SEV(log_level::debug) << "unknown exception:" << what;
            } catch (const std::exception&) {
            }
            disconnect();
            throw;
        }
        __builtin_unreachable();
    }

    void session::connect(const std::string& name, const std::string& proxy, bool use_tor, bool debug)
    {
        exception_wrapper([&] {
            network_parameters net_params{ *network_parameters::get(name) };
            m_impl = std::make_unique<ga_session>(net_params, proxy, use_tor, debug);
            m_impl->connect();
            m_impl->set_notification_handler(m_notification_handler, m_notification_context);
        });
    }

    void session::connect(const network_parameters& net_params, const std::string& proxy, bool use_tor, bool debug)
    {
        exception_wrapper([&] {
            m_impl = std::make_unique<ga_session>(net_params, proxy, use_tor, debug);
            m_impl->connect();
            m_impl->set_notification_handler(m_notification_handler, m_notification_context);
        });
    }

    session::session()
        : m_notification_handler(nullptr)
        , m_notification_context(nullptr)
        , m_impl()
    {
    }
    session::~session() = default;

    void session::disconnect() { m_impl.reset(); }

    void session::register_user(const std::string& mnemonic, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);

        exception_wrapper([&] { m_impl->register_user(mnemonic, user_agent); });
    }

    void session::login(const std::string& mnemonic, const std::string& password, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->login(mnemonic, password, user_agent); });
    }

    void session::login_with_pin(const std::string& pin, const nlohmann::json& pin_data, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->login_with_pin(pin, pin_data, user_agent); });
    }

    void session::login_watch_only(
        const std::string& username, const std::string& password, const std::string& user_agent)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->login_watch_only(username, password, user_agent); });
    }

    bool session::set_watch_only(const std::string& username, const std::string& password)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->set_watch_only(username, password); });
    }

    bool session::remove_account(const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->remove_account(twofactor_data); });
    }

    nlohmann::json session::create_subaccount(const nlohmann::json& details)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->create_subaccount(details); });
    }

    nlohmann::json session::get_subaccounts()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_subaccounts(); });
    }

    void session::change_settings_tx_limits(bool is_fiat, uint32_t total, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { m_impl->change_settings_tx_limits(is_fiat, total, twofactor_data); });
    }

    void session::change_settings_pricing_source(const std::string& currency, const std::string& exchange)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->change_settings_pricing_source(currency, exchange); });
    }

    nlohmann::json session::get_transactions(uint32_t subaccount, uint32_t page_id)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_transactions(subaccount, page_id); });
    }

    void session::set_notification_handler(GA_notification_handler handler, void* context)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl == nullptr);
        m_notification_handler = handler;
        m_notification_context = context;
    }

    nlohmann::json session::get_receive_address(uint32_t subaccount, const std::string& addr_type)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_receive_address(subaccount, addr_type); });
    }

    nlohmann::json session::get_balance(uint32_t subaccount, uint32_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_balance(subaccount, num_confs); });
    }

    nlohmann::json session::get_available_currencies()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_available_currencies(); });
    }

    bool session::is_rbf_enabled()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->is_rbf_enabled(); });
    }

    bool session::is_watch_only()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->is_watch_only(); });
    }

    uint32_t session::get_current_subaccount()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_current_subaccount(); });
    }

    void session::set_current_subaccount(uint32_t subaccount)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->set_current_subaccount(subaccount); });
    }

    std::string session::get_default_address_type()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_default_address_type(); });
    }

    nlohmann::json session::get_twofactor_config()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_twofactor_config(); });
    }

    std::vector<std::string> session::get_all_twofactor_methods()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_all_twofactor_methods(); });
    }

    std::vector<std::string> session::get_enabled_twofactor_methods()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_enabled_twofactor_methods(); });
    }

    void session::set_email(const std::string& email, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->set_email(email, twofactor_data); });
    }

    void session::activate_email(const std::string& code)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->activate_email(code); });
    }

    void session::init_enable_twofactor(
        const std::string& method, const std::string& data, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->init_enable_twofactor(method, data, twofactor_data); });
    }

    void session::enable_twofactor(const std::string& method, const std::string& code)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->enable_twofactor(method, code); });
    }

    void session::enable_gauth(const std::string& code, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->enable_gauth(code, twofactor_data); });
    }

    void session::disable_twofactor(const std::string& method, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->disable_twofactor(method, twofactor_data); });
    }

    void session::twofactor_request_code(
        const std::string& method, const std::string& action, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->twofactor_request_code(method, action, twofactor_data); });
    }

    nlohmann::json session::reset_twofactor(const std::string& email)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->reset_twofactor(email); });
    }

    nlohmann::json session::confirm_twofactor_reset(
        const std::string& email, bool is_dispute, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->confirm_twofactor_reset(email, is_dispute, twofactor_data); });
    }

    nlohmann::json session::cancel_twofactor_reset(const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->cancel_twofactor_reset(twofactor_data); });
    }

    nlohmann::json session::set_pin(const std::string& mnemonic, const std::string& pin, const std::string& device)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->set_pin(mnemonic, pin, device); });
    }

    nlohmann::json session::get_unspent_outputs(uint32_t subaccount, uint32_t num_confs)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_unspent_outputs(subaccount, num_confs); });
    }

    nlohmann::json session::get_unspent_outputs_for_private_key(
        const std::string& private_key, const std::string& password, uint32_t unused)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper(
            [&] { return m_impl->get_unspent_outputs_for_private_key(private_key, password, unused); });
    }

    nlohmann::json session::create_transaction(const nlohmann::json& details)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper(
            [&] { return create_ga_transaction(*this, m_impl->get_network_parameters(), details); });
    }

    nlohmann::json session::sign_transaction(const nlohmann::json& details)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return sign_ga_transaction(*this, details); });
    }

    nlohmann::json session::send_transaction(const nlohmann::json& details, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return send_ga_transaction(*this, details, twofactor_data); });
    }

    void session::send_nlocktimes()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->send_nlocktimes(); });
    }

    void session::set_transaction_memo(
        const std::string& txhash_hex, const std::string& memo, const std::string& memo_type)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->set_transaction_memo(txhash_hex, memo, memo_type); });
    }

    nlohmann::json session::get_transaction_details(const std::string& txhash_hex)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_transaction_details(txhash_hex); });
    }

    std::string session::get_system_message()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_system_message(); });
    }

    nlohmann::json session::get_fee_estimates()
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_fee_estimates(); });
    }

    std::string session::get_mnemonic_passphrase(const std::string& password)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->get_mnemonic_passphrase(password); });
    }

    void session::ack_system_message(const std::string& system_message)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        exception_wrapper([&] { m_impl->ack_system_message(system_message); });
    }

    nlohmann::json session::convert_amount(const nlohmann::json& amount_json)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->convert_amount(amount_json); });
    }

    nlohmann::json session::encrypt(const nlohmann::json& input_json)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->encrypt(input_json); });
    }

    nlohmann::json session::decrypt(const nlohmann::json& input_json)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return exception_wrapper([&] { return m_impl->decrypt(input_json); });
    }

    std::vector<unsigned char> session::output_script(uint32_t subaccount, const nlohmann::json& data) const
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->output_script(subaccount, data); // Note no exception_wrapper
    }

    amount session::get_min_fee_rate() const
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->get_min_fee_rate(); // Note no exception_wrapper
    }

    bool session::have_subaccounts() const
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->have_subaccounts(); // Note no exception_wrapper
    }
    uint32_t session::get_block_height() const
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->get_block_height(); // Note no exception_wrapper
    }
    amount session::get_dust_threshold() const
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->get_dust_threshold(); // Note no exception_wrapper
    }

    nlohmann::json session::get_spending_limits() const
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->get_spending_limits(); // Note no exception_wrapper
    }
    void session::sign_input(const wally_tx_ptr& tx, uint32_t index, const nlohmann::json& u) const
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->sign_input(tx, index, u); // Note no exception_wrapper
    }

    nlohmann::json session::send(const nlohmann::json& details, const nlohmann::json& twofactor_data)
    {
        GA_SDK_RUNTIME_ASSERT(m_impl != nullptr);
        return m_impl->send_transaction(details, twofactor_data); // Note no exception_wrapper
    }
} // namespace sdk
} // namespace ga
