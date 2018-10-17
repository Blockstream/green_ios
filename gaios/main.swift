//
//  main.swift
//  gaios
//
//  Created by Strahinja Markovic on 10/16/18.
//  Copyright © 2018 Blockstream.inc All rights reserved.
//

import UIKit

UIApplicationMain(
    CommandLine.argc,
    UnsafeMutableRawPointer(CommandLine.unsafeArgv)
        .bindMemory(
            to: UnsafeMutablePointer<Int8>.self,
            capacity: Int(CommandLine.argc)),
    NSStringFromClass(CustomApplication.self),
    NSStringFromClass(AppDelegate.self)
)
