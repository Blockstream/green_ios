import com.blockstream.libgreenaddress.GASDK;
import com.blockstream.libwally.Wally;

public class WSSLogin {

    private final static String DEFAULT_MNEMONIC =
          "pony void civil theme thank acoustic insect also cruel arrive reform normal edit awesome deputy ugly wasp eager stumble rule time mask apart critic";

    public static int counter = 0; // Note: Not threadsafe!

    public static void main(final String args[]) throws Exception {
        if (!Wally.isEnabled() && !GASDK.isEnabled())
            throw new RuntimeException();

        String network = "testnet";
        int debug = GASDK.GA_TRUE;
        for (final String arg : args) {
            if (arg.equals("-l")) {
                network = "localtest";
            } else if (arg.equals("-q")) {
                debug = GASDK.GA_FALSE;
            }
        }

        GASDK.NotificationHandler handler = new GASDK.NotificationHandler(){
            public void onNewNofification(final Object session, final Object jsonObject)
            {
                System.out.println(jsonObject.toString());
                WSSLogin.counter += 1;
            }
        };

        GASDK.setNotificationHandler(handler);

        final Object session = GASDK.create_session();
        GASDK.connect(session, network, debug);

        GASDK.register_user(session, DEFAULT_MNEMONIC);
        GASDK.login(session, DEFAULT_MNEMONIC, "");

        final byte[] random_bytes = GASDK.get_random_bytes(32);
        final String mnemonic = GASDK.generate_mnemonic();

        if (false) { // Change to true to test notification delivery
            while (WSSLogin.counter < 10) {
                Thread.sleep(1000);
            }
        }
     }
}
