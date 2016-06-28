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
    
    class func canTrack () -> Bool {
        
        skPaymentQueue = NSClassFromString("SKPaymentQueue")
        if let nsobject = OneSignalTrackIAP.skPaymentQueue as? NSObjectProtocol {
            if nsobject.performSelector(NSSelectorFromString("canMakePayments")).takeUnretainedValue() as? Bool == true { return true }
        }
        
        return false
    }
    
    
    override init() {
        
        super.init()
        
        let defaultQueue = (OneSignalTrackIAP.skPaymentQueue as? NSObjectProtocol)?.performSelector(NSSelectorFromString("defaultQueue"))
        (defaultQueue as? NSObjectProtocol)?.performSelector(NSSelectorFromString("addTransactionObserver:"), withObject: self)
    }
    
    func paymentQueue(queue: AnyClass, updatedTransactions transactions : NSArray) {
        skusToTrack = NSMutableDictionary()
        var skPayment : AnyObject?
        
        for transaction in transactions {
            if let state = transaction.valueForKey("transactionState") as? NSInteger where state == 1 {
                skPayment = transaction.valueForKey("payment")
                let sku = skPayment?.performSelector(NSSelectorFromString("productIdentifier")).takeUnretainedValue() as? NSString
                var qty : Int32 = 0
                if let q = skPayment?.valueForKey("quantity") as? NSInteger { qty = Int32(q) }
                if sku != nil {
                    if let sku_dict = skusToTrack![sku!] as? NSMutableDictionary {
                        var oldCount : Int32 = 0
                        if let old = skusToTrack![sku!]?["count"] as? NSNumber { oldCount = old.intValue }
                        sku_dict.setObject(NSNumber(int: (qty + oldCount)), forKey: "count")
                    }
                    else { skusToTrack![sku!] = NSMutableDictionary(object: NSNumber(int: qty), forKey: "count") }
                }
            }
        }
        
        if skusToTrack!.count > 0 { getProductInfo(skusToTrack!.allKeys)}
    }
    
    func getProductInfo(productIdentifiers: NSArray) {
        
        let SKProductsRequestClass : AnyClass? = NSClassFromString("SKProductsRequest")
        let productsRequest : AnyObject? = SKProductsRequestClass?.alloc()
        (productsRequest as? NSObjectProtocol)?.performSelector(NSSelectorFromString("initWithProductIdentifiers:"), withObject: NSSet(array: productIdentifiers as [AnyObject]))
        productsRequest?.setValue(self, forKey: "delegate")
        (productsRequest as? NSObjectProtocol)?.performSelector(NSSelectorFromString("start"))
        
    }
    
    
    func productsRequest(request: NSObject, didReceiveResponse response: NSObject) {
        let arrayOfPurchases = NSMutableArray()
        
        if let products = response.valueForKey("products") as? NSArray {
            for product in products {
                if let sku = product.valueForKey("productIdentifier") as? NSString, purchase = skusToTrack![sku] as? NSMutableDictionary {
                    purchase["sku"] = sku
                    purchase["amount"] = product.valueForKey("price") as? NSDecimalNumber
                    purchase["iso"] = (product.valueForKey("priceLocale") as? NSLocale)?.objectForKey(NSLocaleCurrencyCode)
                    if let count = purchase["count"] as? NSNumber where count.intValue == 1 {
                        purchase.removeObjectForKey("count")
                    }
                    arrayOfPurchases.addObject(purchase)
                }
            }
            
            if arrayOfPurchases.count > 0 {
                OneSignal.defaultClient.performSelector(#selector(OneSignal.sendPurchases(_:)), withObject: arrayOfPurchases)
            }
        }
    }
    
    
}
