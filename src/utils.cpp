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
        GA_SDK_RUNTIME_ASSERT(wally_bzero(&tsc, sizeof tsc) == WALLY_OK);

        std::array<unsigned char, 64 + 32 + 8> buf;
        GA_SDK_RUNTIME_ASSERT(RAND_bytes(buf.data(), 32) == 1);

        {
            int random_device = open("/dev/urandom", O_RDONLY);
            GA_SDK_RUNTIME_ASSERT(random_device != -1);
            const auto random_device_ptr = std::unique_ptr<int, std::function<void(int*)>>(
                &random_device, [](int* device) { ::close(*device); });

            GA_SDK_RUNTIME_ASSERT(static_cast<size_t>(read(random_device, buf.data(), 32)) == 32);
        }

        std::array<unsigned char, SHA512_LEN> sha512;
        {
            std::unique_lock<std::mutex> l{ curr_state_mutex };

            std::copy(curr_state.begin(), curr_state.end(), buf.data() + 64);
            std::copy(reinterpret_cast<unsigned char*>(&nonce), reinterpret_cast<unsigned char*>(&nonce) + 8,
                buf.data() + 96);
            ++nonce;

            GA_SDK_RUNTIME_ASSERT(wally_sha512(buf.data(), buf.size(), sha512.data(), sha512.size()) == WALLY_OK);

            std::copy(sha512.begin() + 32, sha512.end(), curr_state.data());
        }

        std::copy(sha512.begin(), sha512.begin() + siz, static_cast<unsigned char*>(bytes));

        GA_SDK_RUNTIME_ASSERT(wally_bzero(sha512.data(), sha512.size()) == WALLY_OK);
    }

    wally_string_ptr hex_from_bytes(const unsigned char* bytes, size_t siz)
    {
        char* s = nullptr;
        GA_SDK_RUNTIME_ASSERT(wally_hex_from_bytes(bytes, siz, &s) == WALLY_OK);
        return wally_string_ptr(s, &wally_free_string);
    }

    std::vector<unsigned char> bytes_from_hex(const char* hex, size_t siz)
    {
        std::vector<unsigned char> bytes(siz / 2);
        size_t written;
        GA_SDK_RUNTIME_ASSERT(wally_hex_to_bytes(hex, bytes.data(), bytes.size(), &written) == WALLY_OK);
        bytes.resize(written);
        return bytes;
    }

    std::array<unsigned char, BIP39_ENTROPY_LEN_256> mnemonic_to_bytes(
        const std::string& mnemonic, const std::string& lang)
    {
        const struct words* w = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip39_get_wordlist(lang.c_str(), &w) == WALLY_OK);

        std::array<unsigned char, BIP39_ENTROPY_LEN_256> bytes;
        size_t written = 0;
        GA_SDK_RUNTIME_ASSERT(
            bip39_mnemonic_to_bytes(w, mnemonic.c_str(), bytes.data(), bytes.size(), &written) == WALLY_OK);
        GA_SDK_RUNTIME_ASSERT(written == BIP39_ENTROPY_LEN_256);

        return bytes;
    }

    wally_string_ptr mnemonic_from_bytes(const unsigned char* bytes, size_t siz, const char* lang)
    {
        const struct words* w = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip39_get_wordlist(lang, &w) == WALLY_OK);
        char* s = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_from_bytes(w, bytes, siz, &s) == WALLY_OK);
        return wally_string_ptr(s, &wally_free_string);
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
        const struct words* w = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip39_get_wordlist(lang, &w) == WALLY_OK);
        GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_from_bytes(w, entropy.data(), entropy.size(), output) == WALLY_OK);
        return GA_OK;
    } catch (const std::exception& ex) {
        return GA_ERROR;
    }
}

int GA_validate_mnemonic(const char* lang, const char* mnemonic)
{
    try {
        const struct words* w = nullptr;
        GA_SDK_RUNTIME_ASSERT(bip39_get_wordlist(lang, &w) == WALLY_OK);
        GA_SDK_RUNTIME_ASSERT(bip39_mnemonic_validate(w, mnemonic) == WALLY_OK);
        return GA_TRUE;
    } catch (const std::exception& ex) {
        return GA_FALSE;
    }
}
