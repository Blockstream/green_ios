#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <array>
#include <chrono>
#include <functional>
#include <iostream>
#include <memory>
#include <mutex>

#ifdef __x86_64
#include <x86intrin.h>
#endif

#include <openssl/rand.h>

#include "boost_wrapper.hpp"

#include "include/assertion.hpp"
#include "utils.hpp"

#include "include/utils.h"

#if defined _WIN32 || defined WIN32 || defined __CYGWIN__
#include "bcrypt.h"
#endif

namespace ga {
namespace sdk {

    // use the same strategy as bitcoin core
    void get_random_bytes(std::size_t num_bytes, void* output_bytes, std::size_t siz)
    {
        static std::mutex curr_state_mutex;
        static std::array<unsigned char, 32> curr_state = { { 0 } };
        static uint64_t nonce = 0;

        // We only allow fetching up to 32 bytes of random data as bits beyond
        // this expose the final bytes of the sha512 we use to update curr_state.
        GA_SDK_RUNTIME_ASSERT(num_bytes <= 32 && num_bytes <= siz);

        int64_t tsc = 0;
#ifdef __x86_64
        unsigned int unused;
        tsc = __rdtscp(&unused);
#elif defined _ARM_ARCH_ISA_A64
        // see https://github.com/google/benchmark
        int64_t tsc;
        asm volatile("mrs %0, cntvct_el0" : "r="(tsc));
#elif defined __ARM_ARCH_7A__ || defined __ARM_ARCH_7S__
        // see https://github.com/google/benchmark
        uint32_t pmccntr;
        uint32_t pmuseren;
        uint32_t pmcntenset;
        asm volatile("mrc p15, 0, %0, c9, c14, 0" : "=r"(pmuseren));
        if ((pmuseren & 1) != 0) {
            asm volatile("mrc p15, 0, %0, c9, c12, 1" : "=r"(pmcntenset));
            if ((pmcntenset & 0x80000000ul) != 0) {
                asm volatile("mrc p15, 0, %0, c9, c13, 0" : "=r"(pmccntr));
                tsc = static_cast<int64_t>(pmccntr) * 64;
            }
        }
#endif
        if (!tsc) {
            tsc = std::chrono::high_resolution_clock::now().time_since_epoch().count();
        }

        RAND_add(&tsc, sizeof tsc, 1.5);
        wally::clear(&tsc, sizeof tsc);

        // 32 bytes from openssl, 32 from os random source, 32 from state, 8 from nonce
        std::array<unsigned char, 32 + 32 + 32 + 8> buf;
        GA_SDK_RUNTIME_ASSERT(RAND_bytes(buf.data(), 32) == 1);

        {
#if !defined _WIN32 && !defined WIN32 && !defined __CYGWIN__
            int random_device = open("/dev/urandom", O_RDONLY | O_CLOEXEC);
            GA_SDK_RUNTIME_ASSERT(random_device != -1);
            const auto random_device_ptr = std::unique_ptr<int, std::function<void(int*)>>(
                &random_device, [](const int* device) { ::close(*device); });

            GA_SDK_RUNTIME_ASSERT(static_cast<size_t>(read(random_device, buf.data() + 32, 32)) == 32);
#else
            GA_SDK_RUNTIME_ASSERT(BCryptGenRandom(NULL, buf.data() + 32, 32, BCRYPT_USE_SYSTEM_PREFERRED_RNG) == 0x0);
#endif
        }

        std::array<unsigned char, SHA512_LEN> hashed;
        {
            std::unique_lock<std::mutex> l{ curr_state_mutex };

            std::copy(curr_state.begin(), curr_state.end(), buf.data() + 64);
            std::copy(reinterpret_cast<unsigned char*>(&nonce), reinterpret_cast<unsigned char*>(&nonce) + 8,
                buf.data() + 96);
            ++nonce;

            sha512(buf, hashed);
            std::copy(hashed.begin() + 32, hashed.end(), curr_state.data());
        }

        std::copy(hashed.begin(), hashed.begin() + siz, static_cast<unsigned char*>(output_bytes));

        wally::clear(hashed);
    }

    uint32_t get_uniform_uint32_t(uint32_t upper_bound)
    {
        // Algorithm from the PCG family of random generators
        const uint32_t lower_threshold = -upper_bound % upper_bound;
        while (true) {
            uint32_t v;
            get_random_bytes(sizeof(v), &v, sizeof(v));
            if (v >= lower_threshold) {
                return v % upper_bound;
            }
        }
    }

    static std::vector<unsigned char> bytes_from_hex(const char* hex, size_t siz, bool rev)
    {
        std::vector<unsigned char> buff(siz / 2);
        GA_SDK_RUNTIME_ASSERT(hex_to_bytes(hex, buff) == buff.size());
        if (rev)
            std::reverse(buff.begin(), buff.end());
        return buff;
    }

    std::vector<unsigned char> bytes_from_hex(const char* hex, size_t siz) { return bytes_from_hex(hex, siz, false); }

    std::vector<unsigned char> bytes_from_hex_rev(const char* hex, size_t siz)
    {
        return bytes_from_hex(hex, siz, true);
    }

    // FIXME: secure_array
    std::vector<unsigned char> mnemonic_to_bytes(const std::string& mnemonic)
    {
        // FIXME: secure_array
        std::vector<unsigned char> entropy(BIP39_ENTROPY_LEN_288);
        size_t written = bip39_mnemonic_to_bytes(nullptr, mnemonic, entropy);
        GA_SDK_RUNTIME_ASSERT(written == BIP39_ENTROPY_LEN_256 || written == BIP39_ENTROPY_LEN_288);
        entropy.resize(written);
        return entropy;
    }

    std::string mnemonic_from_bytes(const unsigned char* entropy, size_t siz)
    {
        char* s;
        bip39_mnemonic_from_bytes(nullptr, gsl::make_span(entropy, siz), &s);
        return detail::make_string(s);
    }

    std::string generate_mnemonic() { return mnemonic_from_bytes(get_random_bytes<32>().data(), 32); }

    nlohmann::json parse_bitcoin_uri(const std::string& uri)
    {
        auto&& split = [](const std::string& uri, const std::string& c) {
            std::vector<std::string> ss;
            boost::algorithm::split(ss, uri, boost::is_any_of(c));
            return ss;
        };

        nlohmann::json parsed;

        if (boost::algorithm::starts_with(uri, "bitcoin:")) {
            std::string v = uri;
            if (uri.find('?') != std::string::npos) {
                // FIXME: Issue 68
                // FIXME: BIP21 allows multiple args separated with '&'
                // FIXME: If we encounter args prefixed "req-" and don't handle them, fail the parse
                // FIXME: Take either the lablel or message and set the tx memo field with it if not set
                // FIXME: URL unescape the arguments before returning
                const auto recipient_amount = split(uri, "?");
                const auto amount = split(recipient_amount[1], "=");
                if (amount.size() == 2 && amount[0] == "amount") {
                    parsed["btc"] = amount[1];
                }
                v = recipient_amount[0];
            }
            const auto recipient = split(v, ":");
            if (recipient.size() == 2) {
                parsed["address"] = recipient[1];
            }
        }

        return parsed;
    }
} // namespace sdk
} // namespace ga

int GA_get_random_bytes(size_t num_bytes, unsigned char* output_bytes, size_t len)
{
    try {
        ga::sdk::get_random_bytes(num_bytes, output_bytes, len);
        return GA_OK;
    } catch (const std::exception& e) {
        return GA_ERROR;
    }
}

int GA_generate_mnemonic(char** output)
{
    try {
        const auto entropy = ga::sdk::get_random_bytes<32>();
        ga::sdk::bip39_mnemonic_from_bytes(nullptr, entropy, output);
        return GA_OK;
    } catch (const std::exception& e) {
        return GA_ERROR;
    }
}

int GA_validate_mnemonic(const char* mnemonic)
{
    try {
        bip39_mnemonic_validate(nullptr, mnemonic);
        return GA_TRUE;
    } catch (const std::exception& e) {
        return GA_FALSE;
    }
}

// FIXME: Get rid of this
void GA_copy_string(const char* src, char** dst)
{
    GA_SDK_RUNTIME_ASSERT(src);
    GA_SDK_RUNTIME_ASSERT(dst);

    const auto len = strlen(src);
    *dst = new char[len + 1];
    std::copy(src, src + len, *dst);
    *(*dst + len) = 0;
}

void GA_destroy_string(const char* str) { delete[] str; }
