#include "include/boost_wrapper.hpp"
#include "include/containers.hpp"
#include "include/twofactor.h"
#include "include/utils.hpp"
#include "utils.hpp"

namespace {
const char* DUMMY_CODE = "555555";

std::string generate_random_email() { return "@@" + ga::sdk::hex_from_bytes(ga::sdk::get_random_bytes<8>()); }

void destroy_json(const nlohmann::json& json)
{
    nlohmann::json* non_const = const_cast<nlohmann::json*>(&json);
    GA_destroy_json(reinterpret_cast<GA_json*>(non_const));
}

nlohmann::json* get_twofactor_config(struct GA_session* session)
{
    GA_json* config_c = nullptr;
    GA_SDK_RUNTIME_ASSERT(GA_get_twofactor_config(session, &config_c) == GA_OK);
    return reinterpret_cast<nlohmann::json*>(config_c);
}

const nlohmann::json& assert_twofactor_status(
    const nlohmann::json& config, const std::string& method, bool enabled, bool confirmed, const std::string& data)
{
    const auto& subconfig = config[method];

    GA_SDK_RUNTIME_ASSERT(subconfig.value("enabled", !enabled) == enabled);
    GA_SDK_RUNTIME_ASSERT(subconfig.value("confirmed", !confirmed) == confirmed);

    const std::string subconfig_data = subconfig.value("data", std::string());
    GA_SDK_RUNTIME_ASSERT(boost::algorithm::starts_with(subconfig_data, data));
    return subconfig;
}

struct GA_twofactor_call* assert_twofactor_change_settings(
    struct GA_session* session, const std::string& method, const nlohmann::json& subconfig)
{
    const GA_json* enable_config_c = reinterpret_cast<const GA_json*>(&subconfig);
    struct GA_twofactor_call* call = nullptr;
    GA_SDK_RUNTIME_ASSERT(GA_change_settings_twofactor(session, method.c_str(), enable_config_c, &call) == GA_OK);
    return call;
}

void assert_call_status(struct GA_twofactor_call* call, const std::string& status_str, bool step = true,
    const std::string& explicit_method = std::string())
{
    GA_json* status_c = nullptr;
    GA_SDK_RUNTIME_ASSERT(GA_twofactor_get_status(call, &status_c) == GA_OK);
    const nlohmann::json& status = *reinterpret_cast<nlohmann::json*>(status_c);
    GA_SDK_RUNTIME_ASSERT(status["status"] == status_str);

    if (step) {
        // Take the next step in the state machine
        if (status_str == "request_code") {
            const std::vector<std::string> methods = status["methods"];
            GA_SDK_RUNTIME_ASSERT(!methods.empty());
            const std::string method = explicit_method.empty() ? methods.front() : explicit_method;
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_request_code(call, method.c_str()) == GA_OK);
        } else if (status_str == "resolve_code") {
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_resolve_code(call, DUMMY_CODE) == GA_OK);
        } else if (status_str == "call") {
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_call(call) == GA_OK);
        } else if (status_str == "done") {
            GA_destroy_twofactor_call(call);
        }
    }
    destroy_json(status);
}

static void test_twofactor(struct GA_session* session, const std::string& method)
{
    const nlohmann::json& config = *get_twofactor_config(session);
    const nlohmann::json& current_subconfig = assert_twofactor_status(config, method, false, false, std::string());

    std::string data, expected_data;
    if (method == "email") {
        data = generate_random_email();
        // FIXME: expected_data should be the masked email
    } else if (method == "gauth") {
        data = current_subconfig["data"]; // Get seed from existing config
        expected_data = "***"; // Seed should be masked after enabling
    } else {
        data = "+112345678"; // sms/phone
        // FIXME: expected_data should be the masked number
    }

    nlohmann::json subconfig = { { "enabled", true }, { "confirmed", true }, { "data", data } };

    struct GA_twofactor_call* call = assert_twofactor_change_settings(session, method, subconfig);

    // Assert and step through the enable state machine
    assert_call_status(call, "call");
    // Note no request code since we have no 2fa set up at this point
    assert_call_status(call, "resolve_code");
    assert_call_status(call, "call");
    assert_call_status(call, "done");

    // method should now be enabled
    const nlohmann::json& new_config = *get_twofactor_config(session);
    assert_twofactor_status(new_config, method, true, true, expected_data);

    destroy_json(new_config);
    destroy_json(config);

    // We can now disable the method
    subconfig["enabled"] = false;
    subconfig["confirmed"] = false;
    call = assert_twofactor_change_settings(session, method, subconfig);

    // Assert and step through the disable state machine
    assert_call_status(call, "request_code");
    assert_call_status(call, "resolve_code");
    assert_call_status(call, "call");
    assert_call_status(call, "done");

    // The method should now be disabled
    // For email, the email address will remain confirmed, for other methods
    // confirmed and enabled are synonymous
    const bool confirmed = method == "email";
    const nlohmann::json& disabled_config = *get_twofactor_config(session);
    assert_twofactor_status(disabled_config, method, false, confirmed, std::string());
    destroy_json(disabled_config);

    GA_destroy_session(session);
}

void test_set_email_only(struct GA_session* session)
{
    // Set email without enabling it for two factor
    const std::string email = generate_random_email();
    nlohmann::json subconfig = { { "enabled", false }, { "confirmed", true }, { "data", email } };

    struct GA_twofactor_call* call = assert_twofactor_change_settings(session, "email", subconfig);
    assert_call_status(call, "call");
    // Note no request code since we have no 2fa set up at this point
    assert_call_status(call, "resolve_code");
    assert_call_status(call, "call");
    assert_call_status(call, "done");
}

} // namespace

int main(int argc, char* argv[])
{
    struct options* options;
    parse_cmd_line_arguments(argc, argv, &options);

    if (options->testnet) {
        std::cerr << "Skipping test (requires local environment)" << std::endl;
        return GA_OK;
    }

    const std::vector<std::string> all_methods = { "gauth", "sms", "phone", "email" };
    for (const auto& method : all_methods) {
        test_twofactor(create_new_wallet(options), method);
    }

    test_set_email_only(create_new_wallet(options));

    return GA_OK;
}
