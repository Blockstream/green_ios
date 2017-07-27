import com.blockstream.libgreenaddress.GASDK;
import com.blockstream.libwally.Wally;

public class wss_connect {
    public static void main(String args[]) throws Exception {
        if (!Wally.isEnabled() && !GASDK.isEnabled()) {
            throw new RuntimeException();
        }
        Wally.bip39_get_wordlist("en");
        Object session = GASDK.create_session();
        GASDK.connect(session, GASDK.GA_NETWORK_TESTNET, GASDK.GA_TRUE);
    }
}
