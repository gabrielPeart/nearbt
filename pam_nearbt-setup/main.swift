//
//  main.swift
//  pam_nearbt-setup
//
//  Created by guoc on 23/03/2016.
//  Copyright © 2016 guoc. All rights reserved.
//

import Foundation
import CoreBluetooth

class CentralDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var valueReadFromPeripheral = dispatch_semaphore_create(0)
    var targetPeripheral: CBPeripheral?
    
    let serviceUUID = CBUUID(string: kServiceUUID)
    let characteristicUUID = CBUUID(string: kCharacteristicUUID)
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == .PoweredOn {
            central.scanForPeripheralsWithServices([serviceUUID], options: nil)
        }
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        peripheral.delegate = self
        targetPeripheral = peripheral
        central.connectPeripheral(peripheral, options: nil)
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Fail to connect peripheral: \(error?.localizedDescription)")
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        guard let service = peripheral.services?.last where service.UUID == serviceUUID else {
            print("Target service is not found.")
            return
        }
        peripheral.discoverCharacteristics([characteristicUUID], forService:service)
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        guard let characteristic = service.characteristics?.last where characteristic.UUID == characteristicUUID else {
            print("Target characteristic is not found.")
            return
        }
        peripheral.readValueForCharacteristic(characteristic)
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let error = error {
            fatalError("Setup failure: \(error.localizedDescription)")
        }
        
        dispatch_semaphore_signal(valueReadFromPeripheral)
        
        return
    }
    
}

func installPAM() {
    print("(1/3) Install PAM")
    let pamSourcePath = "/usr/local/lib/security/pam_nearbt.so"
    let pamTargetPath = "/usr/lib/pam/pam_nearbt.so"
    if NSFileManager.defaultManager().fileExistsAtPath(pamTargetPath) {
        print("Already installed.")
        return
    }
    let command_ln = "ln -fs \(pamSourcePath) \(pamTargetPath)"
    let command_chown = "chown -h root:wheel \(pamTargetPath)"
    let command_chmod = "chmod -h 444 \(pamTargetPath)"
    print("The following command will create a symbolic link \(pamTargetPath) to \(pamSourcePath) and set permissions and ownership.")
    print("```")
    print(command_ln)
    print(command_chown)
    print(command_chmod)
    print("```")
    print("To allow these, type your password in the authentication dialog.")
    let script = "do shell script \"\(command_ln); \(command_chown); \(command_chmod)\" with administrator privileges"
    let appleScript = NSAppleScript(source: script)
    guard appleScript?.executeAndReturnError(nil) != nil else {
        fatalError("Fail to link pam_nearbt.so")
    }
    print("Success.")
}

func setupPeripheral(peripheralUUID: NSUUID) {
    print("(2/3) Setup Peripheral")
    let peripheralConfigurationFilePath = NSString(string:kGlobalPeripheralConfigurationFilePath).stringByExpandingTildeInPath
    if NSFileManager.defaultManager().fileExistsAtPath(peripheralConfigurationFilePath) {
        print("\(peripheralConfigurationFilePath) exists, overwrite? (y/n) ", terminator:"")
        if let response = readLine(stripNewline: true) where response != "y" && response != "Y" {
            print("Canceled.")
            return
        }
    }
    NSFileManager.defaultManager().createFileAtPath(peripheralConfigurationFilePath, contents: peripheralUUID.UUIDString.dataUsingEncoding(NSUTF8StringEncoding), attributes: [NSFilePosixPermissions:NSNumber(short:0400)])
    print("Success.")
    return
}

func setupSecret() {
    print("(3/3) Setup Secret")
    if NSFileManager.defaultManager().fileExistsAtPath(kDefaultGlobalSecretFilePath) {
        print("\(kDefaultGlobalSecretFilePath) exists, overwrite? (y/n) ", terminator:"")
        if let response = readLine(stripNewline: true) where response != "y" && response != "Y" {
            print("Canceled.")
            return
        }
    }
    var secret = ""
    repeat {
        secret = String.fromCString(getpass("Please enter your secret: ")) ?? ""
    } while secret.isEmpty
    NSFileManager.defaultManager().createFileAtPath(kDefaultGlobalSecretFilePath, contents: secret.dataUsingEncoding(NSUTF8StringEncoding), attributes: [NSFilePosixPermissions:NSNumber(short:0400)])
    print("Success.")
}

func setupPAM() {
    print("Now you could add pam_nearbt.so in some files under /etc/pam.d/")
    print()
    print("e.g.")
    print("Add the following line at the beginning of /etc/pam.d/screensaver, so that you can unlock screensaver without password by using NearBT.")
    print("auth       sufficient     pam_nearbt.so min_rssi=-55 timeout=10")
    print("Note: this example is only for testing. It may increase security risks.")
}

// MARK: - main() -

installPAM()
print()

print("Launch NearBT on your device, set secret if necessary and turn on \"Enabled\"")
print("Bluetooth pairing may be requested.")
print()

let delegate = CentralDelegate()
let centralManager = CBCentralManager(delegate: delegate, queue: dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0))

dispatch_semaphore_wait(delegate.valueReadFromPeripheral, DISPATCH_TIME_FOREVER)

guard let targetPeripheral = delegate.targetPeripheral else {
    fatalError("Fail to get peripheral UUID.")
}

setupPeripheral(targetPeripheral.identifier)
print()

setupSecret()
print()

print("Setup finished.")
print()

setupPAM()
print()

