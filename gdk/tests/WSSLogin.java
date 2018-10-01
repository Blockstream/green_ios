import com.blockstream.libgreenaddress.GASDK;

public class WSSLogin {
    private final static String DEFAULT_MNEMONIC =
          "pony void civil theme thank acoustic insect also cruel arrive reform normal edit awesome deputy ugly wasp eager stumble rule time mask apart critic";
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
        GASDK.register_user(session, DEFAULT_MNEMONIC);
        GASDK.login(session, DEFAULT_MNEMONIC);
    }
}
