import com.blockstream.libgreenaddress.GASDK;

public class WSSLogin {
    private final static String DEFAULT_MNEMONIC =
          "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive " +
          "spike pond industry time hero trim verb mammal asthma";
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
