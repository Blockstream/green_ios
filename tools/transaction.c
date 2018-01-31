#include "internal.h"

#include <ccan/ccan/endian/endian.h>

#include <include/wally_crypto.h>
#include <include/wally_transaction.h>

#include <limits.h>

#define ALLOC_TX_SIZ(siz)                                                                                              \
    if (!output)                                                                                                       \
        return WALLY_EINVAL;                                                                                           \
    *output = wally_malloc(siz);                                                                                       \
    if (!*output)                                                                                                      \
        return WALLY_ENOMEM;                                                                                           \
    clear((void *)*output, siz)

#define ALLOC_TX_WITNESS()                                                                                             \
    ALLOC_TX_SIZ(sizeof(struct tx_witness))

#define ALLOC_TX_INPUT()                                                                                               \
    ALLOC_TX_SIZ(sizeof(struct tx_input))

#define ALLOC_TX_OUTPUT()                                                                                              \
    ALLOC_TX_SIZ(sizeof(struct tx_output))

#define ALLOC_RAW_TX()                                                                                                 \
    ALLOC_TX_SIZ(sizeof(struct raw_tx))

uint8_t script_encode_op_n(uint8_t v)
{
    if (v == 0)
        return OP_0;
    return OP_1 + v - 1;
}

int script_encode_data(
    const unsigned char* data,
    size_t data_len,
    unsigned char* bytes_out,
    size_t len,
    size_t* written)
{
    unsigned char b;

    if (!bytes_out || !len || !written)
        return WALLY_EINVAL;
    if (len < 1 + data_len)
        return WALLY_EINVAL;

    if (!data_len)
        *bytes_out++ = OP_0;
    else if (data_len == 1) {
        if (!data)
            return WALLY_EINVAL;
        b = data[0];
        if (b >= 1 && b <= 16)
            *bytes_out++ = script_encode_op_n(b);
        else
            *bytes_out++ = 1;
    }
    else if (data_len < OP_PUSHDATA1)
        *bytes_out++ = data_len;
    else if (data_len < 256)
        *bytes_out++ = OP_PUSHDATA1;
    else if (data_len < 65536)
        *bytes_out++ = OP_PUSHDATA2;
    else
        return WALLY_EINVAL;

    memcpy(bytes_out, data, data_len);

    *written = 1 + data_len;

    return WALLY_OK;
}

int script_encode_op(
    unsigned char opcode,
    unsigned char* bytes_out,
    size_t len,
    size_t* written)
{
    if (!bytes_out || len < 1 || !written)
        return WALLY_EINVAL;

    *bytes_out = opcode;
    *written = 1;

    return WALLY_OK;
}

int script_encode_small_num(
    unsigned char num,
    unsigned char* bytes_out,
    size_t len,
    size_t* written)
{
    if (!bytes_out || len < 1 || !written || num > 16)
        return WALLY_EINVAL;

    *bytes_out = script_encode_op_n(num);
    *written = 1;

    return WALLY_OK;
}

inline size_t compact_size_of(uint64_t size)
{
    if (size < 253)
        return sizeof(unsigned char);
    else if (size <= USHRT_MAX)
        return sizeof(unsigned char) + sizeof(uint16_t);
    else if (size <= UINT_MAX)
        return sizeof(unsigned char) + sizeof(uint32_t);
    __builtin_unreachable();
}

static inline size_t compact_size_to_bytes(uint64_t size, unsigned char* bytes_out)
{
    size_t written = 0;
    if (size < 253) {
        uint8_t siz = (uint8_t) size;
        *bytes_out++ = siz;
        written = 1;
    }
    else if (size <= USHRT_MAX) {
        uint16_t n = cpu_to_le16(size);
        *bytes_out++ = 253;
        memcpy(bytes_out, (unsigned char*) &n, sizeof(uint16_t));
        written = 3;
    }
    else if (size <= UINT_MAX) {
        uint32_t n = cpu_to_le32(size);
        *bytes_out++ = 254;
        memcpy(bytes_out, (unsigned char*) &n, sizeof(uint32_t));
        written = 5;
    }
    else {
        __builtin_unreachable();
    }
    return written;
}

int tx_witness_free(const struct tx_witness *tx_witness_in)
{
    if (!tx_witness_in || !tx_witness_in->script_witness)
        return WALLY_EINVAL;
    clear((void*)tx_witness_in->script_witness, tx_witness_in->script_witness_len);
    wally_free((void*)tx_witness_in->script_witness);
    return WALLY_OK;
}

int tx_witness_init_alloc(const unsigned char *script_witness,
                          uint16_t script_witness_len,
                          const struct tx_witness **output)
{
    struct tx_witness *tx_out;

    if (!script_witness || !script_witness_len || !output)
        return WALLY_EINVAL;

    *output = NULL;

    ALLOC_TX_WITNESS();

    tx_out = (struct tx_witness*)*output;

    if (!(tx_out->script_witness = wally_malloc(script_witness_len))) {
        wally_free((void*)tx_out);
        return WALLY_ENOMEM;
    }

    memcpy(tx_out->script_witness, script_witness, script_witness_len);
    tx_out->script_witness_len = script_witness_len;

    printf("INPUT %zu\n", tx_out->script_witness_len);

    return WALLY_OK;
}

WALLY_CORE_API int raw_tx_witness_to_bytes(
    const struct tx_witness *in,
    unsigned char *bytes_out,
    size_t len,
    size_t *written)
{
    size_t n;

    if (!in || !bytes_out || !written)
        return WALLY_EINVAL;

    n = compact_size_to_bytes(in->script_witness_len, bytes_out);
    bytes_out += n;

    memcpy(bytes_out, in->script_witness, in->script_witness_len);
    bytes_out += in->script_witness_len;

    *written = n + in->script_witness_len;

    printf("WRITTENWIT %zu %zu\n", *written, in->script_witness_len);

    return WALLY_OK;
}

int tx_input_free(const struct tx_input *tx_input_in)
{
    int i;

    if (!tx_input_in || !tx_input_in->script)
        return WALLY_EINVAL;
    clear((void*)tx_input_in->script, tx_input_in->script_len);
    wally_free((void*)tx_input_in->script);
    for (i = 0; i < tx_input_in->witness_len; ++i) {
        tx_witness_free(tx_input_in->witness[i]);
    }
    wally_free((void*)tx_input_in->witness);
    clear((void*)tx_input_in, sizeof(struct tx_input));
    wally_free((void*)tx_input_in);

    return WALLY_OK;
}

int tx_input_init_alloc(
    const unsigned char* hash256,
    uint32_t index,
    uint32_t sequence,
    const unsigned char *script,
    size_t script_len,
    const struct tx_witness **witness,
    uint16_t witness_len,
    const struct tx_input **output)
{
    struct tx_input *tx_out;

    if (!hash256 || !script || !script_len || !output)
        return WALLY_EINVAL;

    *output = NULL;

    ALLOC_TX_INPUT();

    tx_out = (struct tx_input*)*output;
    tx_out->index = index;
    tx_out->sequence = sequence;

    memcpy(tx_out->hash256, hash256, SHA256_LEN);

    if (!(tx_out->script = wally_malloc(script_len))) {
        wally_free((void*)tx_out);
        return WALLY_ENOMEM;
    }

    memcpy(tx_out->script, script, script_len);
    tx_out->script_len = script_len;

    if (!witness)
        return WALLY_OK;

    if (!(tx_out->witness = wally_malloc(witness_len * sizeof(struct tx_witness*)))) {
        wally_free((void*)tx_out);
        return WALLY_ENOMEM;
    }

    memcpy(tx_out->witness, witness, witness_len * sizeof(struct tx_witness*));
    tx_out->witness_len = witness_len;

    return WALLY_OK;
}

int raw_tx_in_to_bytes(
    const struct tx_input *in,
    unsigned char *bytes_out,
    size_t len,
    size_t *written)
{
    size_t n;
    uint32_t tmp;

    if (tx_input_size(in, 0, &n) != WALLY_OK)
        return WALLY_EINVAL;

    if (!in || !bytes_out || !written || len < n)
        return WALLY_EINVAL;

    *written = n;

    memcpy(bytes_out, in->hash256, sizeof(in->hash256)); 
    bytes_out += sizeof(in->hash256);

    tmp = cpu_to_le32(in->index);
    memcpy(bytes_out, (const unsigned char*) &tmp, sizeof(uint32_t));
    bytes_out += sizeof(uint32_t);

    n = compact_size_to_bytes(in->script_len, bytes_out);
    bytes_out += n;

    memcpy(bytes_out, in->script, in->script_len);
    bytes_out += in->script_len;

    tmp = cpu_to_le32(in->sequence);
    memcpy(bytes_out, (const unsigned char*) &tmp, sizeof(uint32_t));

    return WALLY_OK;
}

int tx_input_size(const struct tx_input *in, uint32_t flags, size_t *output)
{
    int i;

    if (!in || !output)
        return WALLY_EINVAL;

    *output = sizeof(in->hash256) +
              sizeof(uint32_t) +
              compact_size_of(in->script_len) +
              in->script_len +
              sizeof(uint32_t);

    if (flags & ALLOW_WITNESS_FLAG) {
        if (!in->witness || !in->witness_len)
            return WALLY_OK;

        printf("INPUT SIZ %zu\n", in->witness_len);
        *output += compact_size_of(in->witness_len);
        if (in->witness) {
            for (i = 0; i < in->witness_len; ++i) {
                *output += compact_size_of(in->witness[i]->script_witness_len) + in->witness[i]->script_witness_len;
            }
        }
    }

    printf("INPUT SIZ %zu %zu\n", in->witness_len, *output);
    return WALLY_OK;
}

int tx_output_free(const struct tx_output *tx_output_in)
{
    if (!tx_output_in || !tx_output_in->script)
        return WALLY_EINVAL;

    clear((void*)tx_output_in->script, tx_output_in->script_len);
    clear((void*)tx_output_in, sizeof(struct tx_output));
    wally_free((void*)tx_output_in->script);
    wally_free((void*)tx_output_in);

    return WALLY_OK;
}

int tx_output_init_alloc(
    int64_t amount,
    const unsigned char* script,
    size_t script_len,
    const struct tx_output **output)
{
    struct tx_output *tx_out;

    if (!output)
        return WALLY_EINVAL;
    *output = NULL;

    if (!script || !script_len)
        return WALLY_EINVAL;

    ALLOC_TX_OUTPUT();

    tx_out = (struct tx_output*)*output;
    tx_out->amount = amount;

    if (!(tx_out->script = wally_malloc(script_len))) {
        wally_free((void*)tx_out);
        return WALLY_ENOMEM;
    }

    memcpy(tx_out->script, script, script_len);

    tx_out->script_len = script_len;

    return WALLY_OK;
}

int raw_tx_output_to_bytes(
    const struct tx_output *in,
    unsigned char *bytes_out,
    size_t len,
    size_t *written)
{
    size_t n;
    uint64_t tmp;

    if (tx_output_size(in, &n) != WALLY_OK)
        return WALLY_EINVAL;

    if (!in || !bytes_out || !written || len < n)
        return WALLY_EINVAL;

    *written = n;

    tmp = cpu_to_le64(in->amount);
    memcpy(bytes_out, (const unsigned char*) &tmp, sizeof(uint64_t));
    bytes_out += sizeof(uint64_t);

    n = compact_size_to_bytes(in->script_len, bytes_out);
    bytes_out += n;

    memcpy(bytes_out, in->script, in->script_len);

    return WALLY_OK;
}

int tx_output_size(const struct tx_output *in, size_t *output)
{
    if (!in || !output)
        return WALLY_EINVAL;

    *output = sizeof(uint64_t) +
              compact_size_of(in->script_len) +
              in->script_len;

    return WALLY_OK;
}

int raw_tx_free(const struct raw_tx *raw_tx_in)
{
    if (!raw_tx_in || !raw_tx_in->in || !raw_tx_in->out)
        return WALLY_EINVAL;

    clear((void*)raw_tx_in->in, raw_tx_in->in_len * sizeof(struct tx_input*));
    clear((void*)raw_tx_in->out, raw_tx_in->out_len * sizeof(struct tx_output*));
    clear((void*)raw_tx_in, sizeof(struct raw_tx));
    wally_free((void*)raw_tx_in->in);
    wally_free((void*)raw_tx_in->out);
    wally_free((void*)raw_tx_in);

    return WALLY_OK;
}

int raw_tx_init_alloc(
    uint32_t locktime,
    const struct tx_input **in,
    size_t in_len,
    const struct tx_output **out,
    size_t out_len,
    const struct raw_tx **output)
{
    struct raw_tx *tx_out;

    if (!output)
        return WALLY_EINVAL;
    *output = NULL;

    if (!in || !in_len || !out || !out_len)
        return WALLY_EINVAL;

    ALLOC_RAW_TX();

    tx_out = (struct raw_tx*)*output;
    tx_out->version = 1;
    tx_out->locktime = locktime;

    if (!(tx_out->in = wally_malloc(in_len * sizeof(struct tx_input*)))) {
        wally_free((void*)tx_out);
        return WALLY_ENOMEM;
    }

    if (!(tx_out->out = wally_malloc(out_len * sizeof(struct tx_output*)))) {
        wally_free((void*)tx_out->in);
        wally_free((void*)tx_out);
        return WALLY_ENOMEM;
    }

    memcpy(tx_out->in, in, in_len * sizeof(struct tx_input*));
    memcpy(tx_out->out, out, out_len * sizeof(struct tx_output*));

    tx_out->in_len = in_len;
    tx_out->out_len = out_len;

    return WALLY_OK;
}

int raw_tx_to_bytes(
    const struct raw_tx *in,
    unsigned char *bytes_out,
    size_t len,
    size_t *written)
{
    size_t n;
    size_t i;
    size_t j;
    uint32_t tmp;

    if (raw_tx_byte_length(in, ALLOW_WITNESS_FLAG, &n) != WALLY_OK)
        return WALLY_EINVAL;

    if (!in || !bytes_out || !written || len < n)
        return WALLY_EINVAL;

    *written = 0;

    tmp = cpu_to_le32(in->version);
    memcpy(bytes_out, (const unsigned char*) &tmp, sizeof(uint32_t));
    bytes_out += sizeof(uint32_t);

    *written += sizeof(uint32_t);

    *bytes_out++ = 0x00;
    *bytes_out++ = 0x01;

    *written += 2;

    n = compact_size_to_bytes(in->in_len, bytes_out);
    bytes_out += n;

    *written += n;

    for (i = 0; i < in->in_len; ++i) {
        size_t in_written;
        int r;
        r = raw_tx_in_to_bytes(in->in[i], bytes_out, len, &in_written);
        if (r != WALLY_OK)
            return r;
        bytes_out += in_written;
        *written += in_written;
    }

    n = compact_size_to_bytes(in->out_len, bytes_out);
    bytes_out += n;
    *written += n;

    for (i = 0; i < in->out_len; ++i) {
        size_t out_written;
        int r;
        r = raw_tx_output_to_bytes(in->out[i], bytes_out, len, &out_written);
        if (r != WALLY_OK)
            return r;
        bytes_out += out_written;
        *written += out_written;
    }

    for (i = 0; i < in->in_len; ++i) {
        if (in->in[i]->witness) {
            n = compact_size_to_bytes(in->in[i]->witness_len, bytes_out);
            bytes_out += n;
            *written += n;
            printf("WRITTEN %zu\n", *written);
            for (j = 0; j < in->in[i]->witness_len; ++j) {
                size_t witness_written;
                int r;
                r = raw_tx_witness_to_bytes(in->in[i]->witness[j], bytes_out, len, &witness_written);
                if (r != WALLY_OK)
                    return r;
                printf("WITNESS WRITTEN %zu %zu %zu %d\n", witness_written, len, *written, i);
                bytes_out += witness_written;
                *written += witness_written;
            }
        }
    }

    tmp = cpu_to_le32(in->locktime);
    memcpy(bytes_out, (const unsigned char*) &tmp, sizeof(uint32_t));
    *written += sizeof(uint32_t);

    return WALLY_OK;
}

int raw_tx_byte_length(const struct raw_tx *in, uint32_t flags, size_t *output)
{
    size_t i;
    int has_witnesses;
    int ret;

    if (!in || !output)
        return WALLY_EINVAL;

    *output = sizeof(int32_t) +
              compact_size_of(in->in_len) +
              compact_size_of(in->out_len) +
              sizeof(uint32_t);

    has_witnesses = 0;
    for (i = 0; i < in->in_len; ++i) {
        size_t siz;
        if ((ret = tx_input_size(in->in[i], ALLOW_WITNESS_FLAG, &siz)) != WALLY_OK)
            return ret;
        *output += siz;
        if (in->in[i]->witness)
            ++has_witnesses;
    }

    for (i = 0; i < in->out_len; ++i) {
        size_t siz;
        if ((ret = tx_output_size(in->out[i], &siz)) != WALLY_OK)
            return ret;
        *output += siz;
    }
 
    if ((flags & ALLOW_WITNESS_FLAG) && has_witnesses) {
        *output += 2;
    }

    printf("BYTELENGTH %zu\n", *output);
    return WALLY_OK;
}

int raw_tx_virtual_size(const struct raw_tx *in, size_t *output)
{
    int ret;

    size_t base;
    if ((ret = raw_tx_byte_length(in, 0, &base)) != WALLY_OK)
        return ret;

    size_t total;
    if ((ret = raw_tx_byte_length(in, ALLOW_WITNESS_FLAG, &total)) != WALLY_OK)
        return ret;

    *output = (3 * base + total) / 4;

    return WALLY_OK;
}

int raw_tx_segwit_preimage_size(const struct raw_tx *in,
                                const unsigned char *script,
                                size_t script_len,
                                uint32_t index,
                                uint32_t hash_type,
                                size_t *output)
{
    return WALLY_OK;
}

static int raw_tx_hash_prevouts(const struct raw_tx *in,
                                unsigned char *bytes_out,
                                size_t len)
{
    return WALLY_OK;
}

static int raw_tx_hash_sequence(const struct raw_tx *in,
                                unsigned char *bytes_out,
                                size_t len)
{
    return WALLY_OK;
}

int raw_tx_segwit_preimage(const struct raw_tx *in,
                           const unsigned char *script,
                           size_t script_len,
                           uint32_t index,
                           uint32_t hash_type,
                           unsigned char *bytes_out,
                           size_t len,
                           size_t *written)
{
    unsigned char buffer[SHA256_LEN];
    unsigned char *tmp_buffer;
    size_t tmp_buffer_siz;
    uint32_t tmp;
    int ret;
    int i;

    if (!in || !script || !script_len || !bytes_out)
        return WALLY_EINVAL;

    tmp = cpu_to_le32(in->version);
    memcpy(bytes_out, (const unsigned char*) &tmp, sizeof(uint32_t));
    bytes_out += sizeof(uint32_t);

    if (written)
        *written += sizeof(uint32_t);

    tmp_buffer = NULL;
    tmp_buffer_siz = in->in_len * (SHA256_LEN + sizeof(uint32_t));
    if ((tmp_buffer = wally_malloc(tmp_buffer_siz)) != WALLY_OK)
        return WALLY_ENOMEM;

    for (i = 0; i < in->in_len; ++i) {
        memcpy(tmp_buffer, in->in[i]->hash256, sizeof(in->in[i]->hash256));
        tmp = cpu_to_le32(in->in[i]->index);
        memcpy(tmp_buffer + sizeof(uint32_t), &tmp, sizeof(uint32_t));
        tmp_buffer += SHA256_LEN + sizeof(uint32_t);
    }

    if ((ret = wally_sha256d(tmp_buffer, tmp_buffer_siz, buffer, SHA256_LEN)) != WALLY_OK)
        return ret;

    memcpy(bytes_out, tmp_buffer, SHA256_LEN);
    bytes_out += SHA256_LEN;

    if (written)
       *written += SHA256_LEN;

    wally_free(tmp_buffer);

    tmp_buffer_siz = in->in_len * sizeof(uint32_t);
    if ((tmp_buffer = wally_malloc(tmp_buffer_siz)) != WALLY_OK)
        return WALLY_ENOMEM;

    for (i = 0; i < in->in_len; ++i) {
        tmp = cpu_to_le32(in->in[i]->sequence);
        memcpy(tmp_buffer, (const unsigned char*) &tmp, sizeof(uint32_t));
        tmp_buffer += sizeof(uint32_t);
    }

    if ((ret = wally_sha256d(tmp_buffer, tmp_buffer_siz, buffer, SHA256_LEN)) != WALLY_OK)
        return ret;

    memcpy(bytes_out, tmp_buffer, SHA256_LEN);
    bytes_out += SHA256_LEN;

    if (written)
       *written += SHA256_LEN;

    wally_free(tmp_buffer);

    memcpy(bytes_out, in->in[index]->hash256, SHA256_LEN);
    bytes_out += SHA256_LEN;

    tmp = cpu_to_le32(in->in[index]->index);
    memcpy(bytes_out, (const unsigned char*) &tmp, sizeof(uint32_t));
    bytes_out += sizeof(uint32_t);

    if (written)
        *written += sizeof(uint32_t);

    return WALLY_OK;
}
