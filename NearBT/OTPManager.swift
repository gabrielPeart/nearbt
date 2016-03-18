//
//  PasswordGenerator.swift
//  NearBT
//
//  Created by guoc on 18/03/2016.
//  Copyright © 2016 guoc. All rights reserved.
//

import UIKit
import OneTimePassword

class OTPManager {
    
    let keychainAccountName = "name.guoc.NearBT.secret"
    
    static let sharedManager = OTPManager()
    
    private init() {}
    
    private func clear() {
        let query = [kSecClass as String : kSecClassGenericPassword]
        let status = SecItemDelete(query)
        guard status == noErr else {
            fatalError("Fail to clear keychain.")
        }
    }
    
    func setSecret(secret: String) {
        clear()
        let secAttrAccessible = UserDefaults.sharedUserDefaults.availableWhenDeviceLocked
                              ? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                              : kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let query = [
            kSecClass as String : kSecClassGenericPassword,
            kSecAttrAccessible as String : secAttrAccessible,
            kSecAttrAccount as String : keychainAccountName,
            kSecValueData as String : secret.dataUsingEncoding(NSUTF8StringEncoding)! ]
        SecItemDelete(query)
        let status = SecItemAdd(query, nil)
        if (status == errSecSuccess) {
            UserDefaults.sharedUserDefaults.hasSetSecret = true
        } else {
            fatalError("Fail to save secret in keychain.")
        }
    }
    
    var currentPassword: String? {
        guard UserDefaults.sharedUserDefaults.hasSetSecret else {
            return nil
        }
        let query = [
            kSecClass as String : kSecClassGenericPassword,
            kSecAttrAccount as String : keychainAccountName,
            kSecReturnData as String : kCFBooleanTrue,
            kSecMatchLimit as String : kSecMatchLimitOne ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        guard status == errSecSuccess else {
            fatalError("Fail to retrieve secret from keychain")
        }
        guard let secret = result as? NSData else {
            fatalError("Fail to read secret from keychain")
        }
        
        let deviceName = UIDevice.currentDevice().name
        let token = OTPToken(type: .Timer, secret: secret, name: "NearBT Token", issuer: deviceName)
        
        token.updatePassword()
        let password = token.password
        return password
    }
}
