#ifndef GA_SDK_WALLY_WRAPPER_HPP
#define GA_SDK_WALLY_WRAPPER_HPP
#pragma once

#include <wally_bip32.h>
#include <wally_bip39.h>
#include <wally_core.h>
#include <wally_crypto.h>
#include <wally_transaction.h>

namespace wally
{
    int tx_to_bytes(struct wally_tx* tx, uint32_t flags, std::vector<unsigned char>& bytes_out, size_t* written)
    {
        return wally_tx_to_bytes(tx, flags, bytes_out.data(), bytes_out.size(), written);
    }
}

#endif
