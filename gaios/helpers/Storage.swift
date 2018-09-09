//
//  Storage.swift
//  gaios
//
//  Created by Strahinja Markovic on 8/16/18.
//  Copyright © 2018 Goncalo Carvalho. All rights reserved.
//

import Foundation

class Storage {
    
    static func getDocumentsURL() -> URL? {
        if let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return url
        } else {
            return nil
        }
    }

    static func wipeSettings() {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("settings.json") else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }
    }

    static func wipeNotifications() {
        guard let url = Storage.getDocumentsURL()?.appendingPathComponent("notifications.json") else {
            return
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch let error as NSError {
            print("Error: \(error.domain)")
        }
    }

    static func wipeAll() {
        wipeSettings()
        wipeNotifications()
    }
}
