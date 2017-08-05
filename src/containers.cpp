#include <boost/lexical_cast.hpp>

#include "containers.hpp"

namespace ga {
namespace sdk {

    amount fee_estimates::get_estimate(bool is_instant, uint32_t block) const
    {
        return { (is_instant ? 75 : 60) * 1000 };
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
