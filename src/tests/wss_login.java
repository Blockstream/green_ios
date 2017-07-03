import com.blockstream.libgreenaddress.GASDK;

public class wss_login {
    private final static String DEFAULT_MNEMONIC =
          "ignore roast anger enrich income beef snap busy final dutch banner lobster bird unhappy naive " +
          "spike pond industry time hero trim verb mammal asthma";
    public static void main(String args[]) throws Exception {
        Object session = GASDK.create_session();
        GASDK.connect(session, GASDK.GA_NETWORK_TESTNET, GASDK.GA_TRUE);
        GASDK.register_user(session, DEFAULT_MNEMONIC);
        GASDK.login(session, DEFAULT_MNEMONIC);
    }
}
