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

#include <boost/algorithm/string.hpp>

#include <openssl/rand.h>

#include <wally.hpp>

#include "assertion.hpp"
#include "common.h"
#include "utils.hpp"

#include "utils.h"

namespace ga {
namespace sdk {

    // use the same strategy as bitcoin core
    void get_random_bytes(std::size_t num_bytes, void* bytes, std::size_t siz)
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
        GA_SDK_VERIFY(wally_bzero(&tsc, sizeof tsc));

        // 32 bytes from openssl, 32 from /dev/urandom, 32 from state, 8 from nonce
        std::array<unsigned char, 32 + 32 + 32 + 8> buf;
        GA_SDK_RUNTIME_ASSERT(RAND_bytes(buf.data(), 32) == 1);

        {
            int random_device = open("/dev/urandom", O_RDONLY);
            GA_SDK_RUNTIME_ASSERT(random_device != -1);
            const auto random_device_ptr = std::unique_ptr<int, std::function<void(int*)>>(
                &random_device, [](int* device) { ::close(*device); });

            GA_SDK_RUNTIME_ASSERT(static_cast<size_t>(read(random_device, buf.data() + 32, 32)) == 32);
        }

        std::array<unsigned char, SHA512_LEN> sha512;
        {
            std::unique_lock<std::mutex> l{ curr_state_mutex };

            std::copy(curr_state.begin(), curr_state.end(), buf.data() + 64);
            std::copy(reinterpret_cast<unsigned char*>(&nonce), reinterpret_cast<unsigned char*>(&nonce) + 8,
                buf.data() + 96);
            ++nonce;

            GA_SDK_VERIFY(wally::sha512(buf, sha512));
            std::copy(sha512.begin() + 32, sha512.end(), curr_state.data());
        }

        std::copy(sha512.begin(), sha512.begin() + siz, static_cast<unsigned char*>(bytes));

        GA_SDK_VERIFY(wally_bzero(sha512.data(), sha512.size()));
    }

    wally_string_ptr hex_from_bytes(const unsigned char* bytes, size_t siz)
    {
        char* s;
        GA_SDK_VERIFY(wally_hex_from_bytes(bytes, siz, &s));
        return wally_string_ptr(s);
    }

    secure_vector<unsigned char> bytes_from_hex(const char* hex, size_t siz)
    {
        secure_vector<unsigned char> bytes(siz / 2);
        size_t written;
        GA_SDK_VERIFY(wally_hex_to_bytes(hex, bytes.data(), bytes.size(), &written));
        bytes.resize(written);
        return bytes;
    }

    secure_array<unsigned char, BIP39_ENTROPY_LEN_256> mnemonic_to_bytes(
        const std::string& mnemonic, const std::string& lang)
    {
        struct words* w;
        GA_SDK_VERIFY(bip39_get_wordlist(lang.c_str(), &w));

        secure_array<unsigned char, BIP39_ENTROPY_LEN_256> bytes;
        size_t written = 0;
        GA_SDK_VERIFY(bip39_mnemonic_to_bytes(w, mnemonic.c_str(), bytes.data(), bytes.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == BIP39_ENTROPY_LEN_256);

        return bytes;
    }

    wally_string_ptr mnemonic_from_bytes(const unsigned char* bytes, size_t siz, const char* lang)
    {
        struct words* w;
        GA_SDK_VERIFY(bip39_get_wordlist(lang, &w));
        char* s;
        GA_SDK_VERIFY(bip39_mnemonic_from_bytes(w, bytes, siz, &s));
        return wally_string_ptr(s);
    }

    bitcoin_uri parse_bitcoin_uri(const std::string& s)
    {
        auto&& split = [](const std::string& s, const std::string& c) {
            std::vector<std::string> ss;
            boost::algorithm::split(ss, s, boost::is_any_of(c));
            return ss;
        };

        bitcoin_uri u;
        if (boost::algorithm::starts_with(s, "bitcoin:", boost::is_equal())) {
            std::string v = s;
            if (s.find('?') != std::string::npos) {
                const auto recipient_amount = split(s, "?");
                const auto amount = split(recipient_amount[1], "=");
                if (amount.size() == 2 && amount[0] == "amount") {
                    u.set("amount", amount[1]);
                }
                v = recipient_amount[0];
            }
            const auto recipient = split(v, ":");
            if (recipient.size() == 2) {
                u.set("recipient", recipient[1]);
            }
        }

        return u;
    }
}
}

int GA_get_random_bytes(size_t num_bytes, unsigned char* bytes, size_t siz)
{
    try {
        ga::sdk::get_random_bytes(num_bytes, bytes, siz);
        return GA_OK;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
}

int GA_generate_mnemonic(const char* lang, char** output)
{
    try {
        const auto entropy = ga::sdk::get_random_bytes<32>();
        struct words* w;
        GA_SDK_VERIFY(bip39_get_wordlist(lang, &w));
        GA_SDK_VERIFY(bip39_mnemonic_from_bytes(w, entropy.data(), entropy.size(), output));
        return GA_OK;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
}

int GA_validate_mnemonic(const char* lang, const char* mnemonic)
{
    try {
        struct words* w;
        GA_SDK_VERIFY(bip39_get_wordlist(lang, &w));
        GA_SDK_VERIFY(bip39_mnemonic_validate(w, mnemonic));
        return GA_TRUE;
    } catch (const std::exception& ex) {
        return GA_FALSE;
    }
}

int GA_parse_bitcoin_uri_to_json(const char* uri, char** output)
{
    try {
        GA_SDK_RUNTIME_ASSERT(output);
        const auto elements = ga::sdk::parse_bitcoin_uri(uri);
        const auto s = elements.get_json();
        GA_copy_string(s.c_str(), output);
        return GA_OK;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
}

void GA_copy_string(const char* src, char** dst)
{
    GA_SDK_RUNTIME_ASSERT(src);
    GA_SDK_RUNTIME_ASSERT(dst);

    const auto len = strlen(src);
    *dst = new char[len + 1];
    std::copy(src, src + len, *dst);
    *(dst + len) = 0;
}

void GA_destroy_string(const char* str) { delete[] str; }
