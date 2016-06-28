//
//  OneSignalMobileProvision.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/22/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//


/** embedded.mobileprovision plist format:
 
 AppIDName, // string - TextDetective
 ApplicationIdentifierPrefix[],  // [ string - 66PK3K3KEV ]
 CreationData, // date - 2013-01-17T14:18:05Z
 DeveloperCertificates[], // [ data ]
 Entitlements {
 application-identifier // string - 66PK3K3KEV.com.blindsight.textdetective
 get-task-allow // true or false
 keychain-access-groups[] // [ string - 66PK3K3KEV.* ]
 },
 ExpirationDate, // date - 2014-01-17T14:18:05Z
 Name, // string - Barrierefreikommunizieren (name assigned to the provisioning profile used)
 ProvisionedDevices[], // [ string.... ]
 TeamIdentifier[], // [string - HHBT96X2EX ]
 TeamName, // string - The Blindsight Corporation
 TimeToLive, // integer - 365
 UUID, // string - 79F37E8E-CC8D-4819-8C13-A678479211CE
 Version, // integer - 1
 ProvisionsAllDevices // true or false  ***NB: not sure if this is where this is
 
 */

enum UIApplicationReleaseMode : NSInteger {
    case UIApplicationReleaseUnknown = 0
    case UIApplicationReleaseDev = 1
    case UIApplicationReleaseAdHoc = 2
    case UIApplicationReleaseWildcard = 3
    case UIApplicationReleaseAppStore = 4
    case UIApplicationReleaseSim = 5
    case UIApplicationReleaseEnterprise = 6
}

class OneSignalMobileProvision : NSObject {
    
    class func getMobileProvision() -> NSDictionary? {
        var mobileProvision : NSDictionary? = nil
        
        let provisioningPath = NSBundle.mainBundle().pathForResource("embedded", ofType: "mobileprovision")
        if provisioningPath == nil {return [:]}
        
        // NSISOLatin1 keeps the binary wrapper from being parsed as unicode and dropped as invalid
        let binaryString: NSString?
        do {
            binaryString = try NSString(contentsOfFile: provisioningPath!, encoding: NSISOLatin1StringEncoding)
        } catch _ {
            return nil
        }

        let scanner = NSScanner(string: binaryString! as String)
        var ok = scanner.scanUpToString("<plist", intoString: nil)
        if !ok { print("Unable to find beginning of plist") ; return nil }
        
        var plistString : NSString? = ""
        ok = scanner.scanUpToString("</plist>", intoString: &plistString)
        if !ok { print("Unable to find end of plist") ; return nil }
        
        plistString = (plistString! as String) + "</plist>"
        
        // juggle latin1 back to utf-8!
        if let plistdata_latin1 = plistString!.dataUsingEncoding(NSISOLatin1StringEncoding) {
        
            do {
                mobileProvision = try NSPropertyListSerialization.propertyListWithData(plistdata_latin1, options: NSPropertyListReadOptions.Immutable, format: nil) as? NSDictionary
            }
            catch let error as NSError {
                print("Error parsing extracted plist - \(error)")
            }
        }
        
        return mobileProvision
    }
    
    class func releaseMode() -> UIApplicationReleaseMode {
        
        /*
         1. Not found the provisioning profile? -> return unknown
         2. Keyval count == 0? -> return Simulator or AppStore
         3. val["ProvisionsAllDevices"] is true? -> Enterprise
         */
        
        if let mobileProvision = getMobileProvision() {
            
           // OneSignal.onesignal_Log(OneSignal.ONE_S_LOG_LEVEL.ONE_S_LL_DEBUG, message: "mobileProvision: \(mobileProvision)")
            let entitlements = mobileProvision.objectForKey("Entitlements") as? NSDictionary
            if mobileProvision.count == 0 {
                if TARGET_IPHONE_SIMULATOR != 0 { return .UIApplicationReleaseSim}
                return .UIApplicationReleaseAppStore
            }
            else if (mobileProvision.objectForKey("ProvisionsAllDevices") as? NSNumber)?.boolValue == true {
                return .UIApplicationReleaseEnterprise
            }
            else if let aps_environment = entitlements?["aps-environment"] as? NSString where aps_environment.isEqualToString("development") {
                return .UIApplicationReleaseDev
            }
            else { return .UIApplicationReleaseAppStore}
            
        }
        else {
            
            OneSignal.onesignal_Log(OneSignal.ONE_S_LOG_LEVEL.ONE_S_LL_DEBUG, message: "mobileProvision not found")
            return .UIApplicationReleaseUnknown
        }
        
        
    }
}
