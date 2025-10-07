import Foundation
import green.wally

public class Wally {

    public static let WALLY_EC_SIGNATURE_RECOVERABLE_LEN = EC_SIGNATURE_RECOVERABLE_LEN
    public static let WALLY_BLINDING_FACTOR_LEN = BLINDING_FACTOR_LEN
    public static let BIP39_WORD_LIST_LANG = "en"
    public static let AES_BLOCK_LEN = 16
    public static let HMAC_SHA256_LEN = 32
    public static let EC_PRIVATE_KEY_LEN = 32
    
    /*** address-networks Address network constants */
    public static let WALLY_NETWORK_NONE: UInt32 = 0x00 /** Used for miniscript parsing only */
    public static let WALLY_NETWORK_BITCOIN_MAINNET: UInt32 = 0x01 /** Bitcoin mainnet */
    public static let WALLY_NETWORK_BITCOIN_REGTEST: UInt32 = 0xff  /** Bitcoin regtest: Behaves as testnet except for segwit */
    public static let WALLY_NETWORK_BITCOIN_TESTNET: UInt32 = 0x02 /** Bitcoin testnet */
    public static let WALLY_NETWORK_LIQUID: UInt32 = 0x03 /** Liquid v1 */
    public static let WALLY_NETWORK_LIQUID_REGTEST: UInt32 = 0x04 /** Liquid v1 regtest */
    public static let WALLY_NETWORK_LIQUID_TESTNET: UInt32 = 0x05 /** Liquid v1 testnet */

    /*** miniscript-features Miniscript/Descriptor feature flags */
    public static let WALLY_MS_IS_DESCRIPTOR: UInt32 = 0x020 /** Contains only descriptor expressions (no miniscript) */
    
    public static let BIP32_FLAG_KEY_PUBLIC: UInt32 = Wally.BIP32_FLAG_KEY_PUBLIC
    public static let BIP32_FLAG_SKIP_HASH: UInt32 = Wally.BIP32_FLAG_SKIP_HASH
    
    public static func sigToDer(sig: [UInt8]) throws -> [UInt8] {
        let sigPtr = UnsafePointer(sig)
        let derPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_SIGNATURE_DER_MAX_LEN))
        var written: Int = 0
        if wally_ec_sig_to_der(sigPtr, sig.count, derPtr, Int(EC_SIGNATURE_DER_MAX_LEN), &written) != WALLY_OK {
            throw GaError.GenericError()
        }
        let der = Array(UnsafeBufferPointer(start: derPtr, count: written))
        // derPtr.deallocate()
        return der
    }

    public static func bip32KeyFromParent(
        hdkey: UnsafePointer<ext_key>,
        childNum: UInt32,
        flags: UInt32
    ) throws -> ext_key {
        // let hdkey: UnsafePointer<ext_key> = UnsafePointer(&hdkey)
        var branchkey: UnsafeMutablePointer<ext_key>?
        defer {
            bip32_key_free(branchkey)
        }
        if bip32_key_from_parent_alloc(hdkey, childNum, UInt32(BIP32_FLAG_KEY_PUBLIC | BIP32_FLAG_SKIP_HASH), &branchkey) != WALLY_OK {
            throw GaError.GenericError()
        }
        guard let branchkey = branchkey else {
            throw GaError.GenericError()
        }
        return branchkey.pointee
    }

    public static func bip32KeyToBase58(key: UnsafePointer<ext_key>, flags: UInt32) throws -> String {
        var base58Ptr: UnsafeMutablePointer<Int8>?
        if bip32_key_to_base58(key, flags, &base58Ptr) != WALLY_OK {
            throw GaError.GenericError()
        }
        guard let base58Ptr = base58Ptr else {
            throw GaError.GenericError()
        }
        return String(cString: base58Ptr)
    }

    public static func sha256d(_ input: [UInt8]) throws -> [UInt8] {
        let inputPtr: UnsafePointer<UInt8> = UnsafePointer(input)
        let outputPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(SHA256_LEN))
        if wally_sha256d(inputPtr, input.count, outputPtr, Int(SHA256_LEN)) != WALLY_OK {
            throw GaError.GenericError()
        }
        return Array(UnsafeBufferPointer(start: outputPtr, count: Int(SHA256_LEN)))
    }

    public static func asset_final_vbf(values: [UInt64], numInputs: Int, abf: [UInt8], vbf: [UInt8]) throws -> [UInt8] {
        let valuesPtr: UnsafePointer<UInt64> = UnsafePointer(values)
        let abfPtr: UnsafePointer<UInt8> = UnsafePointer(abf)
        let vbfPtr: UnsafePointer<UInt8> = UnsafePointer(vbf)
        let len = Int(BLINDING_FACTOR_LEN)
        let bufferPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        if wally_asset_final_vbf(valuesPtr, values.count, numInputs, abfPtr, abf.count, vbfPtr, vbf.count, bufferPtr, len) != WALLY_OK {
            throw GaError.GenericError()
        }
        return Array(UnsafeBufferPointer(start: bufferPtr, count: len))
    }

    public static func flatten(_ inputs: [[UInt8]], fixedSize: Int32?) -> [UInt8] {
        return inputs
            .reduce([UInt8](), { (prev, item) in
                if let size = fixedSize, item.count < size {
                    return prev + item + [UInt8](repeating: 0, count: Int(size) - item.count)
                }
                return prev + item
            })
    }

    public static func bip32KeyFromBase58(_ input: String) throws -> green.ext_key {
        var output: UnsafeMutablePointer<green.ext_key>?
        let base58: UnsafeMutablePointer<CChar> = strdup(input)!
        if bip32_key_from_base58_alloc(base58, &output) != WALLY_OK {
            throw GaError.GenericError()
        }
        guard let output = output else {
            throw GaError.GenericError()
        }
        return output.pointee
    }

    public static func bip85FromMnemonic(
        mnemonic: String,
        passphrase: String?,
        isTestnet: Bool = false,
        index: UInt32 = 0,
        numOfWords: UInt32 = 12
    ) -> String? {
        let version = isTestnet ? BIP32_VER_TEST_PRIVATE : BIP32_VER_MAIN_PRIVATE
        let seed512Ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(BIP39_SEED_LEN_512))
        var bip32KeyPtr: UnsafeMutablePointer<green.ext_key>?
        let bip85Ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(HMAC_SHA512_LEN))
        var bip85Len: Int = 0
        var wordlistPtr: OpaquePointer?
        var resultPtr: UnsafeMutablePointer<CChar>?
        defer {
            bip32_key_free(bip32KeyPtr)
        }
        if bip39_mnemonic_to_seed512(strdup(mnemonic)!, passphrase != nil ? strdup(passphrase ?? "")!: nil, seed512Ptr, Int(BIP39_SEED_LEN_512)) != WALLY_OK {
            return nil
        }
        if bip32_key_from_seed_alloc(seed512Ptr, Int(BIP39_SEED_LEN_512), UInt32(version), UInt32(BIP32_FLAG_SKIP_HASH), &bip32KeyPtr) != WALLY_OK {
            return nil
        }
        if bip85_get_bip39_entropy(bip32KeyPtr, strdup(Wally.BIP39_WORD_LIST_LANG)!, numOfWords, index, bip85Ptr, Int(HMAC_SHA512_LEN), &bip85Len) != WALLY_OK {
            return nil
        }
        if bip39_get_wordlist(strdup(Wally.BIP39_WORD_LIST_LANG)!, &wordlistPtr) != WALLY_OK {
            return nil
        }
        if bip39_mnemonic_from_bytes(wordlistPtr, bip85Ptr, bip85Len, &resultPtr) != WALLY_OK {
            return nil
        }
        guard let resultPtr = resultPtr else {
            return nil
        }
        return String(cString: resultPtr)
    }

    public static func getHashPrevouts(
        txhashes: [UInt8],
        outputIdxs: [UInt32]
    ) -> [UInt8]? {
        let txhashesPtr: UnsafePointer<UInt8> = UnsafePointer(txhashes)
        let outputIdxsPtr: UnsafePointer<UInt32> = UnsafePointer(outputIdxs)
        let len = Int(SHA256_LEN)
        let bufferPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        if wally_get_hash_prevouts(txhashesPtr, txhashes.count, outputIdxsPtr, outputIdxs.count, bufferPtr, len) != WALLY_OK {
            return nil
        }
        return Array(UnsafeBufferPointer(start: bufferPtr, count: len))
    }

    public static func txFromBytes(
        tx: [UInt8],
        elements: Bool = false,
        segwit: Bool = false
    ) -> UnsafeMutablePointer<green.wally_tx>? {
        let txPtr: UnsafePointer<UInt8> = UnsafePointer(tx)
        var bufferPtr: UnsafeMutablePointer<green.wally_tx>?
        let flag = elements ? WALLY_TX_FLAG_USE_ELEMENTS : segwit ? WALLY_TX_FLAG_USE_WITNESS : 0
        if wally_tx_from_bytes(txPtr, tx.count, UInt32(flag), &bufferPtr) != WALLY_OK {
            return nil
        }
        return bufferPtr
    }

    public static func txVersion(
        wallyTx: UnsafeMutablePointer<green.wally_tx>
    ) -> UInt32 {
        return wallyTx.pointee.version
    }

    public static func txLocktime(
        wallyTx: UnsafeMutablePointer<green.wally_tx>
    ) -> UInt32 {
        return wallyTx.pointee.locktime
    }

    public static func txGetOutputAsset(
        wallyTx: UnsafeMutablePointer<green.wally_tx>,
        index: Int
    ) -> [UInt8]? {
        let output = wallyTx.pointee.outputs[index]
        return Array(UnsafeBufferPointer(start: output.asset, count: output.asset_len))
    }

    public static func txGetOutputValue(
        wallyTx: UnsafeMutablePointer<green.wally_tx>,
        index: Int
    ) -> [UInt8]? {
        let output = wallyTx.pointee.outputs[index]
        return Array(UnsafeBufferPointer(start: output.value, count: output.value_len))
    }

    public static func ecPrivateKeyVerify(
        privateKey: [UInt8]
    ) -> Bool {
        let keyPtr: UnsafePointer<UInt8> = UnsafePointer(privateKey)
        return wally_ec_private_key_verify(keyPtr, privateKey.count) == WALLY_OK
    }
    public static func bip85FromJade(
        privateKey: [UInt8],
        publicKey: [UInt8],
        label: String,
        payload: [UInt8]
    ) -> String? {
        let privPtr: UnsafePointer<UInt8> = UnsafePointer(privateKey)
        let pubPtr: UnsafePointer<UInt8> = UnsafePointer(publicKey)
        let payloadPtr: UnsafePointer<UInt8> = UnsafePointer(payload)
        let labelPtr = strdup(label)!
        let bip85Ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: payload.count)
        var bip85Len: Int = 0
        var wordlistPtr: OpaquePointer?
        var resultPtr: UnsafeMutablePointer<CChar>?

        if wally_aes_cbc_with_ecdh_key(privPtr, privateKey.count, nil, 0, payloadPtr, payload.count, pubPtr, publicKey.count, labelPtr, label.count, UInt32(AES_FLAG_DECRYPT), bip85Ptr, payload.count, &bip85Len) != WALLY_OK {
            return nil
        }
        if bip39_get_wordlist(strdup(Wally.BIP39_WORD_LIST_LANG)!, &wordlistPtr) != WALLY_OK {
            return nil
        }
        if bip39_mnemonic_from_bytes(nil, bip85Ptr, bip85Len, &resultPtr) != WALLY_OK {
            return nil
        }
        guard let resultPtr = resultPtr else {
            return nil
        }
        return String(cString: resultPtr)
    }
    
    public static func signedPsbtToTxHex(_ psbt: String) -> String? {
        var wallyPsbt: UnsafeMutablePointer<green.wally_psbt>?
        var wallyTx: UnsafeMutablePointer<green.wally_tx>?
        var resultPtr: UnsafeMutablePointer<CChar>?
        
        if wally_psbt_from_base64(psbt, UInt32(WALLY_PSBT_PARSE_FLAG_STRICT), &wallyPsbt) != WALLY_OK {
            return nil
        }
        if wally_psbt_finalize(wallyPsbt, 0) != WALLY_OK {
            return nil
        }
        if wally_psbt_extract(wallyPsbt, 0, &wallyTx) != WALLY_OK {
            return nil
        }
        if wally_tx_to_hex(wallyTx, UInt32(WALLY_TX_FLAG_USE_WITNESS), &resultPtr) != WALLY_OK {
            return nil
        }
        guard let resultPtr = resultPtr else {
            return nil
        }
        return String(cString: resultPtr)
    }
    
    public static func psbtFromBase64(_ psbt: String) throws -> UnsafeMutablePointer<green.wally_psbt> {
        var wallyPsbt: UnsafeMutablePointer<green.wally_psbt>?
        guard wally_psbt_from_base64(psbt, UInt32(WALLY_PSBT_PARSE_FLAG_STRICT), &wallyPsbt) == WALLY_OK,
              let wallyPsbt = wallyPsbt else {
            throw GaError.GenericError("Wally error: psbt from base64")
        }
        return wallyPsbt
    }

    public static func psbtFromBytes(_ binary: [UInt8]) throws -> UnsafeMutablePointer<green.wally_psbt> {
        var wallyPsbt: UnsafeMutablePointer<green.wally_psbt>?
        guard wally_psbt_from_bytes(binary, binary.count, UInt32(WALLY_PSBT_PARSE_FLAG_STRICT), &wallyPsbt) == WALLY_OK,
              let wallyPsbt = wallyPsbt else {
            throw GaError.GenericError("Wally error: psbt from bytes")
        }
        return wallyPsbt
    }

    public static func psbtIsFinalized(_ wallyPsbt: UnsafeMutablePointer<green.wally_psbt>) throws -> Bool {
        var finalized: Int = 0
        guard wally_psbt_is_finalized(wallyPsbt, &finalized) == WALLY_OK else {
            throw GaError.GenericError("Wally error: psbt is finalized")
        }
        return finalized == 1
    }
    public static func psbtIsElements(_ wallyPsbt: UnsafeMutablePointer<green.wally_psbt>) throws -> Bool {
        var elements: Int = 0
        guard wally_psbt_is_elements(wallyPsbt, &elements) == WALLY_OK else {
            throw GaError.GenericError("Wally error: psbt is elements")
        }
        return elements == 1
    }

    public static func psbtIsBase64(_ psbt: String) -> Bool {
        (try? psbtFromBase64(psbt)) != nil
    }

    public static func psbtIsBytes(_ psbt: [UInt8]) -> Bool {
        (try? psbtFromBytes(psbt)) != nil
    }

    public static func psbtSetVersion(_ psbt: UnsafeMutablePointer<green.wally_psbt>, version: UInt32 = UInt32(WALLY_PSBT_VERSION_0)) throws {
        wally_psbt_set_version(psbt, 0, version)
    }
    public static func psbtGetVersion(_ psbt: UnsafeMutablePointer<green.wally_psbt>) throws -> Int {
        var version: Int = 0
        guard wally_psbt_get_version(psbt, &version) == WALLY_OK else {
            throw GaError.GenericError("Wally error: psbt get version")
        }
        return version
    }

    public static func psbtToBase64(_ psbt: UnsafeMutablePointer<green.wally_psbt>) throws -> String {
        var wallyPsbtPtr: UnsafeMutablePointer<CChar>?
        guard wally_psbt_to_base64(psbt, 0, &wallyPsbtPtr) == WALLY_OK,
              let wallyPsbtPtr = wallyPsbtPtr else {
            throw GaError.GenericError("Wally error: psbt to base64")
        }
        return String(cString: wallyPsbtPtr)
    }

    public static func descriptorParse(_ descriptor: String, network: UInt32) -> OpaquePointer? {
        var wallyDescriptor: OpaquePointer?
        if  wally_descriptor_parse(descriptor, nil, network, WALLY_MS_IS_DESCRIPTOR, &wallyDescriptor) != WALLY_OK {
            return nil
        }
        return wallyDescriptor
    }

    public static func descriptorNetwork(_ wallyDescriptor: OpaquePointer) -> Int32 {
        var network: Int32 = 0
        wally_descriptor_get_network(wallyDescriptor, &network)
        return network
    }
}
