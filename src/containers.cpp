#include <boost/lexical_cast.hpp>

#include "containers.hpp"
#include "transaction_utils.hpp"

namespace ga {
namespace sdk {

    namespace {

        static std::map<uint32_t, std::pair<double, uint32_t>> convert_to_block_estimates(
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
                    return { static_cast<long>(fee_rate * 1.1 * 1000 * 1000 * 100) };
                }
                break;
            } else if (actual_block < block) {
                continue;
            }

            return { static_cast<long>(fee_rate * 1000 * 1000 * 100) };
        }

        GA_SDK_RUNTIME_ASSERT(!main_net || !instant);

        return instant ? min_fee_rate * 3 : min_fee_rate;
    }

    tx::tx_view tx::populate_view() const
    {
        std::vector<std::string> received_on;
        std::vector<std::string> recipients;
        std::string counterparty;
        amount total;
        bool has_confidential_recipients{ false };
        bool is_spent{ true };

        const auto l = m_o.get().as<container>();
        const auto eps = l.at("eps").as<std::vector<msgpack::object>>();
        for (auto&& e : eps) {
            const auto ep = e.as<container>();

            const auto social_it = ep.find("social_destination");

            bool external_social{ false };
            if (social_it != ep.end()) {
                const auto type = as<int>(ep, "script_type");
                external_social = type != static_cast<int>(script_type::p2sh_fortified_out)
                    && type != static_cast<int>(script_type::p2sh_p2wsh_fortified_out);
                const auto social_destination = social_it->second.as<msgpack::object>();
                if (social_destination.type == msgpack::type::MAP) {
                    const auto social_type = as<std::string>(ep, "type");
                    counterparty = social_type == "voucher" ? "Voucher" : as<std::string>(ep, "name");
                } else {
                    GA_SDK_RUNTIME_ASSERT(social_destination.type == msgpack::type::STR);
                    counterparty = social_destination.as<std::string>();
                }
            }

            const auto is_credit = as<bool>(ep, "is_credit");
            const auto is_relevant = as<bool>(ep, "is_relevant");

            const auto confidential_it = ep.find("confidential");
            const auto address_it = ep.find("ad");
            const auto value_it = ep.find("value");

            const bool confidential
                = (confidential_it != ep.end() && confidential_it->second.type != msgpack::type::NIL)
                || (value_it != ep.end() && value_it->second.type == msgpack::type::NIL);

            if (is_credit && (!is_relevant || social_it != ep.end())
                && (address_it != ep.end() && address_it->second.type != msgpack::type::NIL)) {
                if (confidential) {
                    has_confidential_recipients = true;
                } else {
                    recipients.push_back(as<std::string>(ep, "ad"));
                }
            }

            if (!is_relevant) {
                continue;
            }

            amount value;
            if (value_it != ep.end() && value_it->second.type != msgpack::type::NIL) {
                value = boost::lexical_cast<amount::value_type>(value_it->second.as<std::string>());
            }

            if (!is_credit) {
                total -= value;
                continue;
            }

            if (!external_social) {
                total += value;
                if (!as<bool>(ep, "is_spent")) {
                    is_spent = false;
                }
            }

            // FIXME: confidential transactions
            const auto address = as<std::string>(ep, "ad");
            received_on.push_back(address);
        }

        tx_view view;

        if (total >= 0) {
            view.type = transaction_type::in;
            // FIXME: missing social
        } else {
            received_on.clear();
            if (recipients.empty() && !has_confidential_recipients) {
                view.type = transaction_type::redeposit;
            } else {
                view.type = transaction_type::out;
                if (counterparty.empty()) {
                    if (!recipients.empty()) {
                        counterparty = recipients.front();
                    } else if (has_confidential_recipients) {
                        counterparty = "Confidential address";
                    }
                }
                if (recipients.size() > 1) {
                    counterparty += ", ...";
                }
            }
        }

        view.received_on = received_on;
        view.counterparty = counterparty;
        view.fee = boost::lexical_cast<amount::value_type>(as<std::string>(l, "fee"));
        view.block_height = as<size_t>(l, "block_height");
        view.size = as<size_t>(l, "size");
        view.hash = as<std::string>(l, "txhash");
        view.instant = as<bool>(l, "instant");
        view.value = total;
        view.is_spent = is_spent;
        // FIXME; missing replaceable

        return view;
    }
}
}
