#include "include/session.hpp"
#include "include/twofactor.h"
#include "src/boost_wrapper.hpp"
#include "src/ga_wally.hpp"
#include "utils.hpp"

namespace {
static const std::string DUMMY_CODE = "555555";
static const std::string INVALID_CODE = "666666";

static std::string generate_random_email() { return "@@" + get_random_string(); }

static void destroy_json(const nlohmann::json& json)
{
    nlohmann::json* non_const = const_cast<nlohmann::json*>(&json);
    GA_destroy_json(reinterpret_cast<GA_json*>(non_const));
}

static nlohmann::json* get_twofactor_config(struct GA_session* session)
{
    GA_json* config_c = nullptr;
    GA_SDK_RUNTIME_ASSERT(GA_get_twofactor_config(session, &config_c) == GA_OK);
    return reinterpret_cast<nlohmann::json*>(config_c);
}

static const nlohmann::json& assert_twofactor_status(
    const nlohmann::json& config, const std::string& method, bool enabled, bool confirmed, const std::string& data)
{
    const auto& subconfig = config[method];

    GA_SDK_RUNTIME_ASSERT(subconfig.value("enabled", !enabled) == enabled);
    GA_SDK_RUNTIME_ASSERT(subconfig.value("confirmed", !confirmed) == confirmed);

    const std::string subconfig_data = subconfig.value("data", std::string());
    GA_SDK_RUNTIME_ASSERT(boost::algorithm::starts_with(subconfig_data, data));
    return subconfig;
}

static struct GA_twofactor_call* assert_twofactor_change_settings(
    struct GA_session* session, const std::string& method, const nlohmann::json& subconfig)
{
    const GA_json* enable_config_c = reinterpret_cast<const GA_json*>(&subconfig);
    struct GA_twofactor_call* call = nullptr;
    GA_SDK_RUNTIME_ASSERT(GA_change_settings_twofactor(session, method.c_str(), enable_config_c, &call) == GA_OK);
    return call;
}

static void assert_call_status(struct GA_twofactor_call* call, const std::string& status_str, bool step = true,
    const std::string& code = DUMMY_CODE, const std::string& explicit_method = std::string())
{
    GA_json* status_c = nullptr;
    GA_SDK_RUNTIME_ASSERT(GA_twofactor_get_status(call, &status_c) == GA_OK);
    const nlohmann::json& status = *reinterpret_cast<nlohmann::json*>(status_c);
    const std::string fetched_status = status["status"];
    GA_SDK_RUNTIME_ASSERT(fetched_status == status_str);

    if (step) {
        // Take the next step in the state machine
        if (status_str == "request_code") {
            const std::vector<std::string> methods = status["methods"];
            GA_SDK_RUNTIME_ASSERT(!methods.empty());
            const std::string method = explicit_method.empty() ? methods.front() : explicit_method;
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_request_code(call, method.c_str()) == GA_OK);
        } else if (status_str == "resolve_code") {
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_resolve_code(call, code.c_str()) == GA_OK);
        } else if (status_str == "call") {
            GA_SDK_RUNTIME_ASSERT(GA_twofactor_call(call) == GA_OK);
        } else if (status_str == "done") {
            GA_destroy_twofactor_call(call);
        }
    }
    destroy_json(status);
}

static struct GA_session* test_twofactor(
    struct GA_session* session, const std::string& method, bool disable = true, bool existing_2fa = false)
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

    // Step through the enable state machine:
    if (!existing_2fa) {
        // We have no 2fa enabled, so our state is 'call' to call init_enable_xxx
        assert_call_status(call, "call");
    } else {
        // We must request a code on our existing 2fa method
        assert_call_status(call, "request_code");
    }
    // After calling, we now need to enter the code of the method we are enabling:
    if (disable) {
        // Try an invalid code
        assert_call_status(call, "resolve_code", true, INVALID_CODE);
        // We can now make the call, which will fail as our code is wrong
        assert_call_status(call, "call");
        // Our state after the failed call goes back to request a code since we
        // still have attempts remaining.
    }
    // Now try a valid code
    assert_call_status(call, "resolve_code");
    // Make the call, which succeeds since the code is correct
    assert_call_status(call, "call");
    // Our status moves to done completing the enable action
    assert_call_status(call, "done");

    // method should now be enabled
    const nlohmann::json& new_config = *get_twofactor_config(session);
    assert_twofactor_status(new_config, method, true, true, expected_data);

    destroy_json(new_config);
    destroy_json(config);

    if (!disable) {
        return session;
    }

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

    return session;
}

static void test_set_email_only(struct GA_session* session)
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

    GA_destroy_session(session);
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

    // Happy path, test enable/disable of a single method
    const std::vector<std::string> all_methods = { "gauth", "sms", "phone", "email" };
    for (const auto& method : all_methods) {
        GA_destroy_session(test_twofactor(create_new_wallet(options), method));
    }

    test_set_email_only(create_new_wallet(options));

    // Enable gauth on a session, then
    // Test enable/disable of a single method with gauth enabled
    struct GA_session* with_gauth = test_twofactor(create_new_wallet(options), "gauth", false);
    const std::vector<std::string> other_methods = { "sms", "phone", "email" };
    for (const auto& method : other_methods) {
        test_twofactor(with_gauth, method, true, true);
    }
    GA_destroy_session(with_gauth);

    return GA_OK;
}
