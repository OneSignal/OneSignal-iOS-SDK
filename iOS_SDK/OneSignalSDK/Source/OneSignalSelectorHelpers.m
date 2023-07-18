/**
 * Modified MIT License
 *
 * Copyright 2017 OneSignal
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * 2. All copies of substantial portions of the Software may only be used in connection
 * with services provided by OneSignal.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "OneSignalSelectorHelpers.h"

BOOL injectSelector(Class targetClass, SEL targetSelector, Class myClass, SEL mySelector) {
    Method newMeth = class_getInstanceMethod(myClass, mySelector);
    IMP newImp = method_getImplementation(newMeth);
    
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    // Keep - class_getInstanceMethod for existing detection.
    //    class_addMethod will successfuly add if the targetClass was loaded twice into the runtime.
    BOOL existing = class_getInstanceMethod(targetClass, targetSelector) != NULL;
    
    if (existing) {
        Method orgMeth = class_getInstanceMethod(targetClass, targetSelector);
        IMP orgImp = method_getImplementation(orgMeth);
        
        // If implementations are the same then the target selector
        // (AKA makeLikeSel) already has the implemenation we want. Without
        // this check we would add the implemenation again as newSel. This will
        // cause the fowarding logic in our code to think there is an orignal
        // implemenation to call, causing an infinite loop.
        if (newImp == orgImp) {
            return existing;
        }
        
        class_addMethod(targetClass, mySelector, newImp, methodTypeEncoding);
        newMeth = class_getInstanceMethod(targetClass, mySelector);
        method_exchangeImplementations(orgMeth, newMeth);
    }
    else
        class_addMethod(targetClass, targetSelector, newImp, methodTypeEncoding);
    
    return existing;
}

IMP injectSelectorSetImp(Class targetClass, SEL targetSelector, Class myClass, IMP newImp) {
    
    //const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    // Keep - class_getInstanceMethod for existing detection.
    //    class_addMethod will successfuly add if the targetClass was loaded twice into the runtime.
    Method orgMeth = class_getInstanceMethod(targetClass, targetSelector);
    
    if (orgMeth) {
        
        IMP orgImp = method_getImplementation(orgMeth);
        
        // If implementations are the same then the target selector
        // (AKA makeLikeSel) already has the implemenation we want. Without
        // this check we would add the implemenation again as newSel. This will
        // cause the fowarding logic in our code to think there is an orignal
        // implemenation to call, causing an infinite loop.
        if (newImp == orgImp) {
            NSLog(@"ECM imps are the same");
            return orgImp;
        }
        
        //class_addMethod(targetClass, mySelector, newImp, methodTypeEncoding);
        //newMeth = class_getInstanceMethod(targetClass, mySelector);
        return method_setImplementation(orgMeth, newImp);
    }
//    else
//        class_addMethod(targetClass, targetSelector, newImp, methodTypeEncoding);
    
    return nil;
}
