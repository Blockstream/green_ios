#ifndef GA_SDK_CONTAINERS_HPP
#define GA_SDK_CONTAINERS_HPP
#pragma once

#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

#include "common.h"

#include "assertion.hpp"
#include <json.hpp>

namespace ga {
namespace sdk {

    enum class transaction_type : uint32_t { in, out, redeposit };

    // Rename from_key to to_key in the given JSON object
    bool json_rename_key(nlohmann::json& data, const std::string& from_key, const std::string& to_key);

    // Add a value to a JSON object if one is not already present under the given key
    template <typename T>
    T json_add_if_missing(nlohmann::json& data, const std::string& key, const T& value, bool or_null = false)
    {
        const auto p = data.find(key);
        if (p == data.end() || (or_null && p->is_null())) {
            data[key] = value;
            return value;
        }
        return *p;
    }

    // Get a value if present and not null, otherwise return a default value
    template <typename T = std::string>
    T json_get_value(const nlohmann::json& data, const std::string& key, const T& default_value = T())
    {
        const auto p = data.find(key);
        if (p == data.end() || p->is_null()) {
            return default_value;
        }
        return *p;
    }
} // namespace sdk
} // namespace ga

#endif
