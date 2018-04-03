#include <queue>
#include <thread>

#include <boost/algorithm/string/join.hpp>
#include <boost/lexical_cast.hpp>

#include "containers.hpp"

namespace ga {
namespace sdk {

    namespace {

        std::map<uint32_t, std::pair<double, uint32_t>> convert_to_block_estimates(
            const fee_estimates::container& estimates)
        {
            std::map<uint32_t, std::pair<double, uint32_t>> c;
            for (auto&& v : estimates) {
                const fee_estimates::container block_estimate = v.second.as<fee_estimates::container>();
                const double fee_rate = std::stod(block_estimate.at("fee_rate").as<std::string>());
                const uint32_t blocks = block_estimate.at("blocks").as<uint32_t>();
                c.emplace(std::stoul(v.first), std::make_pair(fee_rate, blocks));
            }
            return c;
        }
    }

    fee_estimates& fee_estimates::operator=(const msgpack::object& data)
    {
        std::unique_lock<std::mutex> lock{ m_mutex };
        associate(data);
        return *this;
    }

    amount fee_estimates::get_estimate(uint32_t block, bool instant, amount min_fee_rate, bool main_net)
    {
        std::map<uint32_t, std::pair<double, uint32_t>> block_estimates;

        {
            std::unique_lock<std::mutex> lock{ m_mutex };
            block_estimates = convert_to_block_estimates(get_handle().get().as<container>());
        }

        for (auto&& e : block_estimates) {
            const double fee_rate = e.second.first;
            if (fee_rate <= 0.0) {
                continue;
            }
            const double actual_block = e.second.second;

            if (instant) {
                if (actual_block <= 2) {
                    return { static_cast<amount::value_type>(fee_rate * 1.1 * 1000 * 1000 * 100) };
                }
                break;
            }
            if (actual_block < block) {
                continue;
            }

            return { static_cast<amount::value_type>(fee_rate * 1000 * 1000 * 100) };
        }

        GA_SDK_RUNTIME_ASSERT(!main_net || !instant);

        return instant ? min_fee_rate * 3 : min_fee_rate;
    }

    uint32_t login_data::get_min_unused_pointer() const
    {
        // FIXME: there may be gaps so bail out early if diff between top and prev_top is greater than 1
        const auto subaccounts = get<std::vector<msgpack::object>>("subaccounts");
        std::priority_queue<uint32_t, std::vector<uint32_t>> q;
        std::for_each(std::begin(subaccounts), std::end(subaccounts), [&q](const msgpack::object& o) {
            std::map<std::string, msgpack::object> acc;
            o >> acc;
            q.push(acc["pointer"].as<uint32_t>());
        });
        return !q.empty() ? q.top() + 1 : 1;
    }

    std::vector<subaccount> login_data::get_subaccounts() const
    {
        const auto subaccounts = get<std::vector<msgpack::object>>("subaccounts");
        std::vector<subaccount> p;
        p.reserve(subaccounts.size());
        std::copy(std::begin(subaccounts), std::end(subaccounts), std::back_inserter(p));
        return p;
    }

    void login_data::insert_subaccount(const std::string& name, uint32_t pointer, const std::string& receiving_id,
        const std::string& recovery_pub_key, const std::string& recovery_chain_code, const std::string& type)
    {
        std::unordered_map<std::string, msgpack::object> acc;
        acc["name"] = msgpack::object(name);
        acc["pointer"] = msgpack::object(pointer);
        acc["receiving_id"] = msgpack::object(receiving_id);
        acc["type"] = msgpack::object(type);
        acc["2of3_backup_pubkey"] = msgpack::object(recovery_pub_key);
        acc["2of3_backup_chaincode"] = msgpack::object(recovery_chain_code);

        msgpack::zone oz;
        auto subaccounts = get<std::vector<msgpack::object>>("subaccounts");
        subaccounts.emplace_back(msgpack::object(acc, oz));

        msgpack::zone z;
        set("subaccounts", msgpack::object(subaccounts, z));
    }

    void tx::construct_from(const msgpack_object& data)
    {
        associate(data);

        std::vector<std::string> recipients;
        std::vector<std::string> received_on;
        std::string counterparty;
        amount in;
        amount out;

        const auto l = m_o.get().as<container>();
        const auto eps = l.at("eps").as<std::vector<msgpack::object>>();
        for (auto&& e : eps) {
            const auto ep = e.as<container>();

            const auto is_credit = as<bool>(ep, "is_credit");
            const auto is_relevant = as<bool>(ep, "is_relevant");
            const auto ad = as<std::string>(ep, "ad");
            const auto value = as<std::string>(ep, "value");

            if (is_credit && !is_relevant) {
                recipients.push_back(ad);
            }

            if (!is_relevant) {
                continue;
            }

            const long satoshis = boost::lexical_cast<int64_t>(value);

            if (!is_credit) {
                out += satoshis;
            } else {
                in += satoshis;
                // FIXME: confidential transactions
                received_on.push_back(ad);
            }
        }

        const bool tx_in = in > out;
        const amount total = tx_in ? in - out : out - in;
        if (tx_in) {
            set("type", static_cast<uint8_t>(transaction_type::in));
        } else {
            received_on.clear();
            if (recipients.empty()) {
                set("type", static_cast<uint8_t>(transaction_type::redeposit));
            } else {
                set("type", static_cast<uint8_t>(transaction_type::out));
            }
        }

        set("received_on", boost::algorithm::join(received_on, ", "));
        set("counterparty", boost::algorithm::join(recipients, ", "));
        set("timestamp", get<std::string>("created_at"));
        set("hash", get<std::string>("txhash"));
        set("value", total.value());
        set("value_str", tx_in ? to_string(total) : '-' + to_string(total));
        // FIXME; missing replaceable
    }
}
}
