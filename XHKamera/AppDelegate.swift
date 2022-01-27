//
//  AppDelegate.swift
//  XHKamera
//
//  Created by XuHao on 2022/1/27.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        let rootController = ViewController.init()
        window = UIWindow.init(frame: UIScreen.main.bounds)
        window?.rootViewController = rootController

        window?.makeKeyAndVisible()
        return true
    }

}

