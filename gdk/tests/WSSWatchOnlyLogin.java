import com.blockstream.libgreenaddress.GASDK;

public class WSSWatchOnlyLogin {
    // FIXME: use a mnemonic to set watchonly user/pwd via GDK
    private final static String USERNAME = "domenicotestnet";
    private final static String PASSWORD = "domenicotestnet";

    public static void main(final String args[]) throws Exception {
        int network = GASDK.GA_NETWORK_TESTNET;
        for (final String arg : args) {
            if (arg.equals("-l")) {
                network = GASDK.GA_NETWORK_LOCALTEST;
                break;
            }
        }

        final Object session = GASDK.create_session();
        GASDK.connect(session, network, GASDK.GA_TRUE);
        GASDK.login_watch_only(session, USERNAME, PASSWORD);
        final String txs = (String) GASDK.get_transactions(session, 0, 0);
    }
}
