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

#include "assertion.hpp"
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
        wally_bzero(&tsc, sizeof tsc);

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

            hashed = sha512(buf);
            std::copy(hashed.begin() + 32, hashed.end(), curr_state.data());
        }

        std::copy(hashed.begin(), hashed.begin() + siz, static_cast<unsigned char*>(output_bytes));

        wally_bzero(hashed.data(), hashed.size());
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

    static auto bytes_from_hex(const char* hex, size_t siz, bool rev)
    {
        size_t written;
        std::vector<unsigned char> buff(siz / 2);
        GA_SDK_VERIFY(wally_hex_to_bytes(hex, buff.data(), buff.size(), &written));
        GA_SDK_RUNTIME_ASSERT(written == buff.size());
        if (rev) {
            std::reverse(buff.begin(), buff.end());
        }
        return buff;
    }

    std::vector<unsigned char> bytes_from_hex(const char* hex, size_t siz) { return bytes_from_hex(hex, siz, false); }

    std::vector<unsigned char> bytes_from_hex_rev(const char* hex, size_t siz)
    {
        return bytes_from_hex(hex, siz, true);
    }

    std::string decrypt_mnemonic(const std::string& encrypted_mnemonic, const std::string& password)
    {
        const auto entropy = bip39_mnemonic_to_bytes(encrypted_mnemonic);
        GA_SDK_RUNTIME_ASSERT_MSG(entropy.size() == 36, "Invalid encrypted mnemonic");
        const auto ciphertext = gsl::make_span(entropy).first(32);
        const auto salt = gsl::make_span(entropy).last(4);

        std::vector<unsigned char> derived(64);
        scrypt(ustring_span(password), salt, 16384, 8, 8, derived);

        const auto key = gsl::make_span(derived).last(32);
        std::vector<unsigned char> plaintext(32);
        aes(key, ciphertext, AES_FLAG_DECRYPT, plaintext);
        for (int i = 0; i < 32; ++i) {
            plaintext[i] ^= derived[i];
        }

        const auto sha_buffer = sha256d(plaintext);
        const auto salt_ = gsl::make_span(sha_buffer).first(4);
        GA_SDK_RUNTIME_ASSERT_MSG(!memcmp(salt_.data(), salt.data(), salt.size()), "Invalid checksum");

        return bip39_mnemonic_from_bytes(plaintext);
    }

    std::string encrypt_mnemonic(const std::string& plaintext_mnemonic, const std::string& password)
    {
        const auto plaintext = bip39_mnemonic_to_bytes(plaintext_mnemonic);
        const auto sha_buffer = sha256d(plaintext);
        const auto salt = gsl::make_span(sha_buffer).first(4);

        std::vector<unsigned char> derived(64);
        scrypt(ustring_span(password), salt, 16384, 8, 8, derived);
        const auto derivedhalf1 = gsl::make_span(derived).first(32);
        const auto derivedhalf2 = gsl::make_span(derived).last(32);

        std::array<unsigned char, 32> decrypted;
        for (int i = 0; i < 32; ++i) {
            decrypted[i] = plaintext[i] ^ derivedhalf1[i];
        }

        std::vector<unsigned char> ciphertext;
        ciphertext.reserve(36);
        ciphertext.resize(32);
        aes(derivedhalf2, decrypted, AES_FLAG_ENCRYPT, ciphertext);
        ciphertext.insert(ciphertext.end(), salt.begin(), salt.end());

        return bip39_mnemonic_from_bytes(ciphertext);
    }

    // Parse a bitcoin uri as described in bip21/72 and return the components thereof
    //  e.g.
    //  parse_bitcoin_uri('bitcoin:abcdefg?amount=1.1&label=foo')
    //  =>
    //    {'address': 'abcdefg',
    //     'amount': '1.1',
    //     'label': 'foo'}
    //
    // If the uri passed is not a bitcoin uri return a null json object.
    nlohmann::json parse_bitcoin_uri(const std::string& uri)
    {
        // Split a string into a head and tail around the first (leftmost) occurrence
        // of delimiter and return the tuple (head, tail). If delimiter does not occur
        // in input return the tuple (input, '')
        auto&& split = [](const std::string& input, char delimiter) {
            const auto pos = input.find(delimiter);
            const auto endpos = pos == std::string::npos ? input.size() : pos + 1;
            return std::make_tuple(input.substr(0, pos), input.substr(endpos));
        };

        // FIXME: Issue 68
        // FIXME: Take either the label or message and set the tx memo field with it if not set
        // FIXME: URL unescape the arguments before returning
        //
        nlohmann::json parsed;
        std::string scheme, tail;
        std::tie(scheme, tail) = split(uri, ':');
        if (scheme == "bitcoin") {
            std::string address;
            std::tie(address, tail) = split(tail, '?');
            if (!address.empty()) {
                parsed["address"] = address;
            }
            while (!tail.empty()) {
                std::string param, key, value;
                std::tie(param, tail) = split(tail, '&');
                std::tie(key, value) = split(param, '=');
                GA_SDK_RUNTIME_ASSERT_MSG(
                    !boost::algorithm::starts_with(key, "req-"), "Unhandled required bip21 key: " + key);
                parsed.emplace(key, value);
            }
        }
        return parsed;
    }

    // Lookup key in json and if present decode it as hex and return the bytes, if not present
    // return the result of calling f()
    // This is useful in a couple of places where a bytes value can be optionally overridden in json
    template <class F> inline auto json_default_hex(const nlohmann::json& json, const std::string& key, F&& f)
    {
        const auto p = json.find(key);
        return p == json.end() ? f() : bytes_from_hex(p->get<std::string>());
    }

    static std::vector<unsigned char> get_encryption_password(
        const nlohmann::json& input, const std::vector<unsigned char>& default_)
    {
        return json_default_hex(input, "password", [&default_]() { return default_; });
    }

    static auto get_encryption_salt(const nlohmann::json& input)
    {
        auto salt = json_default_hex(input, "salt", []() {
            std::vector<unsigned char> salt(16);
            get_random_bytes(salt.size(), salt.data(), salt.size());
            return salt;
        });
        GA_SDK_RUNTIME_ASSERT_MSG(salt.size() == 16, "Invalid salt length");
        return salt;
    }

    std::string aes_cbc_decrypt(
        const std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN>& key, const std::string& ciphertext)
    {
        const auto ciphertext_bytes = bytes_from_hex(ciphertext);
        const auto iv = gsl::make_span(ciphertext_bytes).first(AES_BLOCK_LEN);
        const auto encrypted = gsl::make_span(ciphertext_bytes).subspan(AES_BLOCK_LEN);
        std::vector<unsigned char> plaintext(encrypted.size());
        aes_cbc(key, iv, encrypted, AES_FLAG_DECRYPT, plaintext);
        GA_SDK_RUNTIME_ASSERT(plaintext.size() <= static_cast<size_t>(encrypted.size()));
        return std::string(plaintext.begin(), plaintext.end());
    }

    std::string aes_cbc_encrypt(
        const std::array<unsigned char, PBKDF2_HMAC_SHA256_LEN>& key, const std::string& plaintext)
    {
        // FIXME: secure_array
        const auto iv = get_random_bytes<AES_BLOCK_LEN>();
        const size_t plaintext_padded_size = (plaintext.size() / AES_BLOCK_LEN + 1) * AES_BLOCK_LEN;
        std::vector<unsigned char> encrypted(AES_BLOCK_LEN + plaintext_padded_size);
        aes_cbc(key, iv, ustring_span(plaintext), AES_FLAG_ENCRYPT, encrypted);
        GA_SDK_RUNTIME_ASSERT(encrypted.size() == plaintext_padded_size);
        encrypted.insert(std::begin(encrypted), iv.begin(), iv.end());
        return hex_from_bytes(encrypted);
    }

    nlohmann::json encrypt_data(const nlohmann::json& input, const std::vector<unsigned char>& default_password)
    {
        const auto password = get_encryption_password(input, default_password);
        GA_SDK_RUNTIME_ASSERT_MSG(!password.empty(), "A password must be provided to encrypt/decrypt");
        const auto salt = get_encryption_salt(input);
        const auto key = pbkdf2_hmac_sha512_256(password, salt);
        const auto plaintext = input.at("plaintext");
        const auto ciphertext = aes_cbc_encrypt(key, plaintext);
        return { { "ciphertext", ciphertext }, { "salt", hex_from_bytes(salt) } };
    }

    nlohmann::json decrypt_data(const nlohmann::json& input, const std::vector<unsigned char>& default_password)
    {
        const auto password = get_encryption_password(input, default_password);
        GA_SDK_RUNTIME_ASSERT_MSG(!password.empty(), "A password must be provided to encrypt/decrypt");
        const auto salt = get_encryption_salt(input);
        const auto key = pbkdf2_hmac_sha512_256(password, salt);
        const auto ciphertext = input.at("ciphertext");
        const auto plaintext = aes_cbc_decrypt(key, ciphertext);
        return { { "plaintext", plaintext } };
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
        GA_SDK_VERIFY(::bip39_mnemonic_from_bytes(nullptr, entropy.data(), entropy.size(), output));
        return GA_OK;
    } catch (const std::exception& e) {
        return GA_ERROR;
    }
}

int GA_validate_mnemonic(const char* mnemonic)
{
    try {
        GA_SDK_VERIFY(bip39_mnemonic_validate(nullptr, mnemonic));
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
