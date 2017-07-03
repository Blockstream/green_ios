import com.blockstream.libgreenaddress.GASDK;

public class wss_connect {
    public static void main(String args[]) throws Exception {
        Object session = GASDK.create_session();
        GASDK.connect(session, GASDK.GA_NETWORK_TESTNET, GASDK.GA_TRUE);
    }
}
