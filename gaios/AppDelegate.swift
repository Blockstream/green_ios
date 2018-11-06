import UIKit




class GreenAddressService: SessionNotificationDelegate {

    func newNotification(dict: [String : Any]) {
        DispatchQueue.main.async {
            let event = dict["event"] as! String
            if (event == "block") {
                let block = dict["block"] as! [String: Any]
                let blockHeight = block["block_height"] as! UInt32
                AccountStore.shared.setBlockHeight(height: blockHeight)
            } else if (event == "transaction") {
                let transaction = dict["transaction"] as! [String: Any]
                let type = transaction["type"] as! String
                let hash = transaction["txhash"] as! String
                var subaccounts = Array<Int>()
                if let accounts = transaction["subaccounts"] as? [Int] {
                    subaccounts.append(contentsOf: accounts)
                }
                if let account = transaction["subaccounts"] as? Int {
                    subaccounts.append(account)
                }
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "transaction"), object: nil, userInfo: ["subaccounts" : subaccounts])
                if (type == "incoming") {
                    print("incoming transaction")
                    self.showIncomingNotification()
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "incomingTX"), object: nil, userInfo: ["subaccounts" : subaccounts])
                } else if (type == "outgoing"){
                    print("outgoing transaction")
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "outgoingTX"), object: nil, userInfo: ["subaccounts" : subaccounts, "txhash" : hash])
                }
            } else if (event == "twofactor_reset") {
                let data = dict["twofactor_reset"] as! [String: Any]
                let active = data["is_active"] as! Bool
                let disputed = data["is_disputed"] as! Bool
                let days = data["days_remaining"] as! Int
                AccountStore.shared.setTwoFactorResetData(isReset: active, isDisputed: disputed, days: days)
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "twoFactorReset"), object: nil, userInfo: ["twoFactorReset" : dict])
            }
        }
    }

    func showIncomingNotification() {
        let window = UIApplication.shared.keyWindow!
        let v = UIView(frame: window.bounds)
        window.addSubview(v);
        v.backgroundColor = UIColor.black
        let label = UILabel()
        label.frame = CGRect(x: 0, y: 0, width: 120, height: 30)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Transaction Received"
        label.textColor = UIColor.white
        label.textAlignment = .center
        v.addSubview(label)
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 220).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 30).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: v, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: v, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0).isActive = true
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.3) {
            v.removeFromSuperview()
        }
    }

    public init() {
       Session.delegate = self
    }

    var session: Session = try! Session()

    var loginData: [String: Any]? = nil

    func getSession() -> Session {
        return self.session
    }

    func getConfirmationPriority() -> String {
        return [3: "High", 6: "Normal", 12: "Low", 24: "Economy"][(loginData!["appearance"] as! [String: Any])["required_num_blocks"] as? Int ?? 24]!
    }
}

func getAppDelegate() -> AppDelegate {
    return UIApplication.shared.delegate as! AppDelegate
}

func getGAService() -> GreenAddressService {
    return getAppDelegate().getService()
}

func getSession() -> Session {
    return getGAService().getSession()
}

var network: Network = Network.TestNet
var proxyIp: String = ""
var proxyPort: String = ""
var torEnabled: Bool = false

func getNetwork() -> Network {
    return network
}

func setNetwork(net: Network) {
    network = net
    saveNetworkSettingsToDisk()
}

func setProxyIp(ip: String) {
    proxyIp = ip
    saveNetworkSettingsToDisk()
}

func setProxyPort(port: String) {
    proxyPort = port
    saveNetworkSettingsToDisk()
}

func setAllNetworkSettings(net: Network, ip: String, port: String, tor: Bool) {
    network = net
    proxyIp = ip
    proxyPort = port
    torEnabled = tor
    saveNetworkSettingsToDisk()
}

class NetworkSettings: Codable {
    var network: String
    var ipAddress: String
    var portNumber: String
    var torEnabled: Bool

    init(network: String, ipAddress: String, portNumber: String, torEnabled: Bool) {
        self.network = network
        self.ipAddress = ipAddress
        self.portNumber = portNumber
        self.torEnabled = torEnabled
    }
}

func getNetworkSettings() -> NetworkSettings {
    return NetworkSettings(network: getNetwork().rawValue, ipAddress:proxyIp, portNumber: proxyPort, torEnabled: torEnabled)
}

func getGdkNetwork(_ network: String) throws -> [String: Any]? {
    var result = try! getNetworks()
    if (!(result?.keys.contains(network))!) {
        throw GaError.GenericError
    }
    return result![network] as? [String: Any]
}

func setDefaultNetworkSetings() {
    setNetwork(net: Network.TestNet)
    proxyPort = ""
    proxyIp = ""
}

func stringForNetwork(net: Network) ->String {
    if(net == Network.MainNet) {
        return "MainNet"
    } else if(net == Network.TestNet) {
        return "TestNet"
    } else if(net == Network.LocalTest) {
        return "LocalTest"
    } else {
        return "RegTest"
    }
}

func networkForString(net: String) -> Network {
    if (net == "mainnet") {
        return Network.MainNet
    } else if (net == "testnet") {
        return Network.TestNet
    } else if (net == "localtest") {
        return Network.LocalTest
    } else {
        return Network.RegTest
    }
}

func loadNetworkSettings() {
    guard let url = Storage.getDocumentsURL()?.appendingPathComponent("network.json") else {
        setDefaultNetworkSetings()
        return
    }
    let decoder = JSONDecoder()
    do {
        let data = try Data(contentsOf: url, options: [])
        let network = try decoder.decode( NetworkSettings.self, from: data)
        setNetwork(net: networkForString(net: network.network))
        proxyPort = network.portNumber
        proxyIp = network.ipAddress
        torEnabled = network.torEnabled
    } catch {
        setDefaultNetworkSetings()
    }
}

func saveNetworkSettingsToDisk() {
    guard let url = Storage.getDocumentsURL()?.appendingPathComponent("network.json") else {
        return
    }
    let encoder = JSONEncoder()
    do {
        let data = try encoder.encode(getNetworkSettings())
        try data.write(to: url, options: [])
    } catch {
        print("error writing network settings to disk")
    }
}


class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let service = GreenAddressService()
    var startTime = DispatchTime.now()
    var endTime = DispatchTime.now()

    var mnemonicWords: [String]? = nil

    func getService() -> GreenAddressService {
        return self.service
    }

    func setMnemonicWords(_ words: [String]) {
        mnemonicWords = words
    }

    func getMnemonicWords() -> [String]? {
        if (mnemonicWords) == nil {
            do {
                let mn = try getSession().getMnemmonicPassphrase(password: "")
                return getMnemonicsArray(mnemonics: mn)
            } catch {
                print("somethin went wrong")
            }
            return nil
        }
        return mnemonicWords
    }

    func getMnemonicWordsString() -> String? {
        return getMnemonicWords()!.joined(separator: " ")
    }

    func getMnemonicsArray(mnemonics: String) -> [String]? {
        let result = mnemonics.components(separatedBy: " ")
        return result
    }

    static func removeKeychainData() {
        removeBioKeychainData()
        removePinKeychainData()
    }

    static func removeBioKeychainData() {
        KeychainHelper.removePassword(service: "bioData", account: "user")
        KeychainHelper.removePassword(service: "bioPassword", account: "user")
    }

    static func removePinKeychainData() {
        KeychainHelper.removePassword(service: "pinData", account: "user")
        KeychainHelper.removePassword(service: "pinPassword", account: "user")
    }

    func connect() {
        DispatchQueue.global(qos: .background).async {
            wrap {
                let netset = getNetworkSettings()
                if(netset.ipAddress != "" && netset.portNumber != "") {
                    let uri = String(format: "socks5://%@:%@/", netset.ipAddress, netset.portNumber)
                    try getSession().connectWithProxy(network: getNetwork(), proxy_uri: uri, use_tor: netset.torEnabled, debug: true)
                } else {
                    try getSession().connect(network: getNetwork(), debug: true)
                }
            }.done {
                print("Connected")
            }.catch { error in
                DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 0.5) {
                    self.connect()
                }
            }
        }
    }

    func disconnect() {
        DispatchQueue.global(qos: .background).async {
            wrap {
                try getSession().disconnect()
            }.done {
                print("Disconnected")
            }.catch { error in
                DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 0.5) {
                    self.disconnect()
                }
            }
        }
    }

    @objc func lockApplication(_ notification: NSNotification) {
        //check if user is loggedIn
        lock()
    }

    func lock() {
        connect()
        print("locking now")
        self.window?.endEditing(true)
        let bioData = KeychainHelper.loadPassword(service: "bioData", account: "user")
        let pinData = KeychainHelper.loadPassword(service: "pinData", account: "user")
        let password = KeychainHelper.loadPassword(service: "bioPassword", account: "user")
        if (bioData != nil && pinData != nil && password != nil) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let firstVC = storyboard.instantiateViewController(withIdentifier: "PinLoginViewController") as! PinLoginViewController
            firstVC.pinData = pinData!
            firstVC.loginMode = true
            firstVC.bioData = bioData!
            firstVC.password = password!
            firstVC.bioAuth = true
            self.window?.rootViewController = firstVC
            self.window?.makeKeyAndVisible()
            return
        } else if(bioData != nil && password != nil) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let firstVC = storyboard.instantiateViewController(withIdentifier: "FaceIDViewController") as! FaceIDViewController
            firstVC.password = password!
            firstVC.pinData = bioData!
            self.window?.rootViewController = firstVC
            self.window?.makeKeyAndVisible()
            return
        } else if (pinData != nil) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let firstVC = storyboard.instantiateViewController(withIdentifier: "PinLoginViewController") as! PinLoginViewController
            firstVC.pinData = pinData!
            firstVC.loginMode = true
            self.window?.rootViewController = firstVC
            self.window?.makeKeyAndVisible()
            return
        } else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let firstVC = storyboard.instantiateViewController(withIdentifier: "InitialViewController") as! UINavigationController
            self.window?.rootViewController = firstVC
            self.window?.makeKeyAndVisible()
        }
    }

    func logout() {
        wrap {
            try getSession().disconnect()
        }.done {
            AccountStore.shared.isWatchOnly = false
        }.catch { error in
            print("problem while logging out")
        }
        lock()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        //AppDelegate.removeKeychainData()
        loadNetworkSettings()

        NotificationCenter.default.addObserver(self, selector: #selector(self.lockApplication(_:)), name: NSNotification.Name(rawValue: "autolock"), object: nil)

        connect()

        let bioData = KeychainHelper.loadPassword(service: "bioData", account: "user")
        let pinData = KeychainHelper.loadPassword(service: "pinData", account: "user")
        let password = KeychainHelper.loadPassword(service: "bioPassword", account: "user")
        if (bioData != nil && pinData != nil && password != nil) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let firstVC = storyboard.instantiateViewController(withIdentifier: "PinLoginViewController") as! PinLoginViewController
            firstVC.pinData = pinData!
            firstVC.loginMode = true
            firstVC.bioData = bioData!
            firstVC.password = password!
            firstVC.bioAuth = true
            self.window?.rootViewController = firstVC
            return true
        } else if(bioData != nil && password != nil) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let firstVC = storyboard.instantiateViewController(withIdentifier: "FaceIDViewController") as! FaceIDViewController
            firstVC.password = password!
            firstVC.pinData = bioData!
            self.window?.rootViewController = firstVC
            return true
        } else if(pinData != nil) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let firstVC = storyboard.instantiateViewController(withIdentifier: "PinLoginViewController") as! PinLoginViewController
            firstVC.pinData = pinData!
            firstVC.loginMode = true
            self.window?.rootViewController = firstVC
            return true
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let firstVC = storyboard.instantiateViewController(withIdentifier: "InitialViewController") as! UINavigationController
        self.window?.rootViewController = firstVC

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("start timer")
        startTime = DispatchTime.now()

        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        connect()
        endTime = DispatchTime.now()
        let timeElapsed = (endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1000000000 //in seconds
        if (timeElapsed < 600) {
            print("time elapsed is less than 5 minutes")
        } else {
            lock()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

