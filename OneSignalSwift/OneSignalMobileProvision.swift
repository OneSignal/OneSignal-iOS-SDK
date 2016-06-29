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
    case uiApplicationReleaseUnknown = 0
    case uiApplicationReleaseDev = 1
    case uiApplicationReleaseAdHoc = 2
    case uiApplicationReleaseWildcard = 3
    case uiApplicationReleaseAppStore = 4
    case uiApplicationReleaseSim = 5
    case uiApplicationReleaseEnterprise = 6
}

class OneSignalMobileProvision : NSObject {
    
    static func getMobileProvision() -> NSDictionary? {
        var mobileProvision : NSDictionary? = nil
        
        let provisioningPath = Bundle.main().pathForResource("embedded", ofType: "mobileprovision")
        if provisioningPath == nil {return [:]}
        
        // NSISOLatin1 keeps the binary wrapper from being parsed as unicode and dropped as invalid
        let binaryString: NSString?
        do {
            binaryString = try NSString(contentsOfFile: provisioningPath!, encoding: String.Encoding.isoLatin1.rawValue)
        } catch _ {
            return nil
        }

        let scanner = Scanner(string: binaryString! as String)
        var ok = scanner.scanUpTo("<plist", into: nil)
        if !ok { OneSignal.onesignal_Log(.one_S_LL_ERROR, message: "Unable to find beginning of plist") ; return nil }
        
        var plistString : NSString? = ""
        ok = scanner.scanUpTo("</plist>", into: &plistString)
        if !ok { OneSignal.onesignal_Log(.one_S_LL_ERROR, message: "Unable to find end of plist") ; return nil }
        
        plistString = (plistString! as String) + "</plist>"
        
        // juggle latin1 back to utf-8!
        if let plistdata_latin1 = plistString!.data(using: String.Encoding.isoLatin1.rawValue) {
        
            do {
                mobileProvision = try PropertyListSerialization.propertyList(from: plistdata_latin1, options: PropertyListSerialization.MutabilityOptions(), format: nil) as? NSDictionary
            }
            catch let error as NSError {
                OneSignal.onesignal_Log(.one_S_LL_ERROR, message: "Error parsing extracted plist - \(error)")
            }
        }
        
        return mobileProvision
    }
    
    static func releaseMode() -> UIApplicationReleaseMode {
        
        /*
         1. Not found the provisioning profile? -> return unknown
         2. Keyval count == 0? -> return Simulator or AppStore
         3. val["ProvisionsAllDevices"] is true? -> Enterprise
         */
        
        if let mobileProvision = getMobileProvision() {
            
           // OneSignal.onesignal_Log(OneSignal..ONE_S_LL_DEBUG, message: "mobileProvision: \(mobileProvision)")
            let entitlements = mobileProvision.object(forKey: "Entitlements") as? NSDictionary
            if mobileProvision.count == 0 {
                if TARGET_IPHONE_SIMULATOR != 0 { return .uiApplicationReleaseSim}
                return .uiApplicationReleaseAppStore
            }
            else if (mobileProvision.object(forKey: "ProvisionsAllDevices") as? NSNumber)?.boolValue == true {
                return .uiApplicationReleaseEnterprise
            }
            else if let aps_environment = entitlements?["aps-environment"] as? NSString where aps_environment.isEqual(to: "development") {
                return .uiApplicationReleaseDev
            }
            else { return .uiApplicationReleaseAppStore}
            
        }
        else {
            
            OneSignal.onesignal_Log(.one_S_LL_DEBUG, message: "mobileProvision not found")
            return .uiApplicationReleaseUnknown
        }
        
        
    }
}
