//
//  OneSignalTrackIAP.swift
//  OneSignalSwift
//
//  Created by Joseph Kalash on 6/21/16.
//  Copyright © 2016 OneSignal. All rights reserved.
//

import Foundation

class OneSignalTrackIAP : NSObject {
    
    static var skPaymentQueue : AnyClass?
    var skusToTrack : NSMutableDictionary?
    
    static func canTrack () -> Bool {
        
        skPaymentQueue = NSClassFromString("SKPaymentQueue")
        if let nsobject = OneSignalTrackIAP.skPaymentQueue as? NSObjectProtocol {
            if nsobject.perform(NSSelectorFromString("canMakePayments")).takeUnretainedValue() as? Bool == true { return true }
        }
        
        return false
    }
    
    
    override init() {
        
        super.init()
        
        let defaultQueue = (OneSignalTrackIAP.skPaymentQueue as? NSObjectProtocol)?.perform(NSSelectorFromString("defaultQueue"))
        let _ = (defaultQueue as? NSObjectProtocol)?.perform(NSSelectorFromString("addTransactionObserver:"), with: self)
    }
    
    func paymentQueue(_ queue: AnyClass, updatedTransactions transactions : NSArray) {
        skusToTrack = NSMutableDictionary()
        var skPayment : AnyObject?
        
        for transaction in transactions {
            if let state = transaction.value(forKey: "transactionState") as? NSInteger where state == 1 {
                skPayment = transaction.value(forKey: "payment")
                let sku = skPayment?.perform(NSSelectorFromString("productIdentifier")).takeUnretainedValue() as? NSString
                var qty : Int32 = 0
                if let q = skPayment?.value(forKey: "quantity") as? NSInteger { qty = Int32(q) }
                if sku != nil {
                    if let sku_dict = skusToTrack![sku!] as? NSMutableDictionary {
                        var oldCount : Int32 = 0
                        if let old = skusToTrack![sku!]?["count"] as? NSNumber { oldCount = old.int32Value }
                        sku_dict.setObject(NSNumber(value: (qty + oldCount)), forKey: "count")
                    }
                    else { skusToTrack![sku!] = NSMutableDictionary(object: NSNumber(value: qty), forKey: "count") }
                }
            }
        }
        
        if skusToTrack!.count > 0 { getProductInfo(skusToTrack!.allKeys)}
    }
    
    func getProductInfo(_ productIdentifiers: NSArray) {
        
        let SKProductsRequestClass : AnyClass? = NSClassFromString("SKProductsRequest")
        let productsRequest : AnyObject? = SKProductsRequestClass?.alloc()
        let _ = (productsRequest as? NSObjectProtocol)?.perform(NSSelectorFromString("initWithProductIdentifiers:"), with: NSSet(array: productIdentifiers as [AnyObject]))
        productsRequest?.setValue(self, forKey: "delegate")
        let _ = (productsRequest as? NSObjectProtocol)?.perform(NSSelectorFromString("start"))
        
    }
    
    func productsRequest(_ request: NSObject, didReceiveResponse response: NSObject) {
        let arrayOfPurchases = NSMutableArray()
        
        if let products = response.value(forKey: "products") as? NSArray {
            for product in products {
                if let sku = product.value(forKey: "productIdentifier") as? NSString, purchase = skusToTrack![sku] as? NSMutableDictionary {
                    purchase["sku"] = sku
                    purchase["amount"] = product.value(forKey: "price") as? NSDecimalNumber
                    purchase["iso"] = (product.value(forKey: "priceLocale") as? Locale)?.object(forKey: Locale.Key.currencyCode)
                    if let count = purchase["count"] as? NSNumber where count.int32Value == 1 {
                        purchase.removeObject(forKey: "count")
                    }
                    arrayOfPurchases.add(purchase)
                }
            }
            
            if arrayOfPurchases.count > 0 {
                OneSignal.sendPurchases(arrayOfPurchases)
            }
        }
    }
    
    
}
