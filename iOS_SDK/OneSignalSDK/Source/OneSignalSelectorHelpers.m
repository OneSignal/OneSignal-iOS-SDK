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

BOOL injectClassSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getClassMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
   
    BOOL existing = class_getClassMethod(addToClass, makeLikeSel) != NULL;
    
    if (existing) {
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        newMeth = class_getClassMethod(addToClass, newSel);
       // Method orgMeth = class_getClassMethod(addToClass, makeLikeSel);
        class_replaceMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
        //method_exchangeImplementations(orgMeth, newMeth);
    }
    else
        class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    
    return existing;
}

BOOL injectSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getInstanceMethod(newClass, newSel);
    IMP newImp = method_getImplementation(newMeth);
    
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    // Keep - class_getInstanceMethod for existing detection.
    //    class_addMethod will successfuly add if the addToClass was loaded twice into the runtime.
    BOOL existing = class_getInstanceMethod(addToClass, makeLikeSel) != NULL;
    
    if (existing) {
        Method orgMeth = class_getInstanceMethod(addToClass, makeLikeSel);
        IMP orgImp = method_getImplementation(orgMeth);
        
        // If implementations are the same then the target selector
        // (AKA makeLikeSel) already has the implemenation we want. Without
        // this check we would add the implemenation again as newSel. This will
        // cause the fowarding logic in our code to think there is an orignal
        // implemenation to call, causing an infinite loop.
        if (newImp == orgImp) {
            return existing;
        }
        
        class_addMethod(addToClass, newSel, newImp, methodTypeEncoding);
        newMeth = class_getInstanceMethod(addToClass, newSel);
        method_exchangeImplementations(orgMeth, newMeth);
    }
    else
        class_addMethod(addToClass, makeLikeSel, newImp, methodTypeEncoding);
    
    return existing;
}

// Try to find out which class to inject to
void injectToProperClass(SEL newSel, SEL makeLikeSel, NSArray* delegateSubclasses, Class myClass, Class delegateClass) {
    
    injectSelector(myClass, newSel, delegateClass, makeLikeSel);
}
