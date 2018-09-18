import com.blockstream.libgreenaddress.GASDK;
import com.blockstream.libwally.Wally;

public class WSSConnect {
    public static void main(final String args[]) throws Exception {
        if (!Wally.isEnabled() && !GASDK.isEnabled()) {
            throw new RuntimeException();
        }
        Wally.bip39_get_wordlist("en");
        int network = GASDK.GA_NETWORK_TESTNET;
        for (final String arg : args) {
            if (arg.equals("-l")) {
                network = GASDK.GA_NETWORK_LOCALTEST;
                break;
            }
        }
        final Object session = GASDK.create_session();
        GASDK.connect(session, network, GASDK.GA_TRUE);
        final byte[] random_bytes = GASDK.get_random_bytes(32);
        final String mnemonic = GASDK.generate_mnemonic("en");
    }
}
