import com.blockstream.libgreenaddress.GASDK;

public class WSSWatchOnlyLogin {
    // FIXME: use a mnemonic to set watchonly user/pwd via GDK
    private final static String USERNAME = "domenicotestnet";
    private final static String PASSWORD = "domenicotestnet";

    public static void main(final String args[]) throws Exception {
        String network = "testnet";
        int debug = GASDK.GA_FALSE;
        for (final String arg : args) {
            if (arg.equals("-l")) {
                network = "localtest";
                break;
            }
            if (arg.equals("-q")) {
                debug = GASDK.GA_TRUE;
                break;
            }
        }

        final Object session = GASDK.create_session();
        try {
        GASDK.connect(session, network, debug);
        GASDK.login_watch_only(session, USERNAME, PASSWORD);
        } catch (final Exception ex) {
            if (network != "testnet") {
                System.out.println("Skipping test (requires testnet or local environment w/proxy)");
                return;
            }
            throw ex;
        }
        final String txs = (String) GASDK.get_transactions(session, 0, 0);
    }
}
