//
//  AppDelegate.swift
//  gaios
//
//  Created by Strahinja Markovic on 7/15/18.
//  Copyright © 2018 Blockstream inc. All rights reserved.
//
import UIKit

class GreenAddressService {
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

func getNetwork() -> Network {
    return network
}

func setNetwork(net: Network) {
    network = net
}

@UIApplicationMain
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
        wrap {
            try getSession().connect(network: getNetwork(), debug: true)
            }.done {
                print("Connected")
            }.catch { error in
                DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 0.5) {
                    self.connect()
                }
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        //AppDelegate.removeKeychainData()
        DispatchQueue.global(qos: .background).async {
            self.connect()
        }
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
            //logout here
            print("time elapsed is larger than 5 minutes")
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
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

