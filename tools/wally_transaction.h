#ifndef LIBWALLY_CORE_TRANSACTION_H
#define LIBWALLY_CORE_TRANSACTION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define OP_0 0x00
#define OP_FALSE = OP_0
#define OP_PUSHDATA1 0x4c
#define OP_PUSHDATA2 0x4d
#define OP_PUSHDATA4 0x4e
#define OP_1NEGATE 0x4f
#define OP_RESERVED 0x50
#define OP_1 0x51
#define OP_TRUE OP_1
#define OP_2 0x52
#define OP_3 0x53
#define OP_4 0x54
#define OP_5 0x55
#define OP_6 0x56
#define OP_7 0x57
#define OP_8 0x58
#define OP_9 0x59
#define OP_10 0x5a
#define OP_11 0x5b
#define OP_12 0x5c
#define OP_13 0x5d
#define OP_14 0x5e
#define OP_15 0x5f
#define OP_16 0x60

#define OP_NOP 0x61
#define OP_VER 0x62
#define OP_IF 0x63
#define OP_NOTIF 0x64
#define OP_VERIF 0x65
#define OP_VERNOTIF 0x66
#define OP_ELSE 0x67
#define OP_ENDIF 0x68
#define OP_VERIFY 0x69
#define OP_RETURN 0x6a

#define OP_TOALTSTACK 0x6b
#define OP_FROMALTSTACK 0x6c
#define OP_2DROP 0x6d
#define OP_2DUP 0x6e
#define OP_3DUP 0x6f
#define OP_2OVER 0x70
#define OP_2ROT 0x71
#define OP_2SWAP 0x72
#define OP_IFDUP 0x73
#define OP_DEPTH 0x74
#define OP_DROP 0x75
#define OP_DUP 0x76
#define OP_NIP 0x77
#define OP_OVER 0x78
#define OP_PICK 0x79
#define OP_ROLL 0x7a
#define OP_ROT 0x7b
#define OP_SWAP 0x7c
#define OP_TUCK 0x7d

#define OP_CAT 0x7e
#define OP_SUBSTR 0x7f
#define OP_LEFT 0x80
#define OP_RIGHT 0x81
#define OP_SIZE 0x82

#define OP_INVERT 0x83
#define OP_AND 0x84
#define OP_OR 0x85
#define OP_XOR 0x86
#define OP_EQUAL 0x87
#define OP_EQUALVERIFY 0x88
#define OP_RESERVED1 0x89
#define OP_RESERVED2 0x8a

#define OP_1ADD 0x8b
#define OP_1SUB 0x8c
#define OP_2MUL 0x8d
#define OP_2DIV 0x8e
#define OP_NEGATE 0x8f
#define OP_ABS 0x90
#define OP_NOT 0x91
#define OP_0NOTEQUAL 0x92

#define OP_ADD 0x93
#define OP_SUB 0x94
#define OP_MUL 0x95
#define OP_DIV 0x96
#define OP_MOD 0x97
#define OP_LSHIFT 0x98
#define OP_RSHIFT 0x99

#define OP_BOOLAND 0x9a
#define OP_BOOLOR 0x9b
#define OP_NUMEQUAL 0x9c
#define OP_NUMEQUALVERIFY 0x9d
#define OP_NUMNOTEQUAL 0x9e
#define OP_LESSTHAN 0x9f
#define OP_GREATERTHAN 0xa0
#define OP_LESSTHANOREQUAL 0xa1
#define OP_GREATERTHANOREQUAL 0xa2
#define OP_MIN 0xa3
#define OP_MAX 0xa4

#define OP_WITHIN 0xa5

#define OP_RIPEMD160 0xa6
#define OP_SHA1 0xa7
#define OP_SHA256 0xa8
#define OP_HASH160 0xa9
#define OP_HASH256 0xaa
#define OP_CODESEPARATOR 0xab
#define OP_CHECKSIG 0xac
#define OP_CHECKSIGVERIFY 0xad
#define OP_CHECKMULTISIG 0xae
#define OP_CHECKMULTISIGVERIFY 0xaf

#define OP_NOP1 0xb0
#define OP_CHECKLOCKTIMEVERIFY 0xb1
#define OP_NOP2 OP_CHECKLOCKTIMEVERIFY
#define OP_CHECKSEQUENCEVERIFY 0xb2
#define OP_NOP3 OP_CHECKSEQUENCEVERIFY
#define OP_NOP4 0xb3
#define OP_NOP5 0xb4
#define OP_NOP6 0xb5
#define OP_NOP7 0xb6
#define OP_NOP8 0xb7
#define OP_NOP9 0xb8
#define OP_NOP10 0xb9

#define OP_SMALLINTEGER 0xfa
#define OP_PUBKEYS 0xfb
#define OP_PUBKEYHASH 0xfd
#define OP_PUBKEY 0xfe

#define OP_INVALIDOPCODE 0xff

WALLY_CORE_API uint8_t script_encode_op_n(uint8_t v);

WALLY_CORE_API int script_encode_data(
    const unsigned char* data,
    size_t data_len,
    unsigned char* bytes_out,
    size_t len,
    size_t* written);

WALLY_CORE_API int script_encode_op(
    unsigned char opcode,
    unsigned char* bytes_out,
    size_t len,
    size_t* written);

WALLY_CORE_API int script_encode_small_num(
    unsigned char num,
    unsigned char* bytes_out,
    size_t len,
    size_t* written);

#define TRANSACTION_SEQUENCE_FINAL 0xffffffff

struct tx_input {
    unsigned char hash256[32];
    uint32_t index;
    uint32_t sequence;
    unsigned char pad1[14];
    unsigned char *script;
    size_t script_len;
};

WALLY_CORE_API int tx_input_free(const struct tx_input *in);

WALLY_CORE_API int tx_input_init_alloc(
    const unsigned char *hash256,
    uint32_t index,
    uint32_t sequence,
    const unsigned char *script,
    size_t script_len,
    const struct tx_input **output);

WALLY_CORE_API int raw_tx_in_to_bytes(
    const struct tx_input *in,
    unsigned char *bytes_out,
    size_t len,
    size_t *written);

WALLY_CORE_API int tx_input_size(const struct tx_input *in, size_t *output);

struct tx_output {
    int64_t amount;
    unsigned char *script;
    size_t script_len;
};

WALLY_CORE_API int tx_output_free(const struct tx_output *tx_output_in);

WALLY_CORE_API int tx_output_init_alloc(
    int64_t amount,
    const unsigned char* script,
    size_t script_len,
    const struct tx_output **output);

WALLY_CORE_API int raw_tx_output_to_bytes(
    const struct tx_output *in,
    unsigned char *bytes_out,
    size_t len,
    size_t *written);

WALLY_CORE_API int tx_output_size(const struct tx_output *in, size_t *output);

#define TRANSACTION_LATEST_VERSION 2
#define TRANSACTION_MAX_STANDARD_VERSION 2

struct raw_tx {
    int32_t version;
    uint32_t locktime;
    struct tx_input **in;
    size_t in_len;
    struct tx_output **out;
    size_t out_len;
};

WALLY_CORE_API int raw_tx_free(const struct raw_tx *raw_tx_in);

WALLY_CORE_API int raw_tx_init_alloc(
    uint32_t locktime,
    const struct tx_input **in,
    size_t in_len,
    const struct tx_output **out,
    size_t out_len,
    const struct raw_tx **output);

WALLY_CORE_API int raw_tx_to_bytes(
    const struct raw_tx *in,
    unsigned char *bytes_out,
    size_t len,
    size_t *written);

WALLY_CORE_API int raw_tx_size(const struct raw_tx *in, size_t *output);

#ifdef __cplusplus
}
#endif

#endif
