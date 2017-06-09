#ifndef GA_SDK_SESSION_CALL_RESULT_HPP
#define GA_SDK_SESSION_CALL_RESULT_HPP
#pragma once

#include <string>
#include <unordered_map>

#include <msgpack.hpp>

namespace ga {
namespace sdk {

    class session_call_result final {
    public:
        using container = std::unordered_map<std::string, msgpack::object>;

        void associate(const container& data) { m_data = data; }

        template <typename T> T get(const std::string& path) { return m_data.at(path).as<T>(); }

    private:
        container m_data;
    };
}
}

#endif
