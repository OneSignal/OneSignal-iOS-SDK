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

// Just for debugging
void DumpObjcMethods(Class clz) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(clz, &methodCount);
    
    
    NSLog(@"Found %d methods on '%s'\n", methodCount, class_getName(clz));
    
    
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        
        
        NSLog(@"'%s' has method named '%s' of encoding '%s'\n",
              class_getName(clz),
              sel_getName(method_getName(method)),
              method_getTypeEncoding(method));
    }
    
    
    free(methods);
}

// Use swizzleClassMethodWithCategoryImplementation over injectStaticSelector
BOOL injectStaticSelector(Class newClass, SEL newSel, Class addToClass, SEL makeLikeSel) {
    Method newMeth = class_getClassMethod(newClass, newSel);
    IMP imp = method_getImplementation(newMeth);
    
    const char* methodTypeEncoding = method_getTypeEncoding(newMeth);
    // Keep - class_getInstanceMethod for existing detection.
    //    class_addMethod will successfuly add if the addToClass was loaded twice into the runtime.
    BOOL existing = class_getClassMethod(addToClass, makeLikeSel) != NULL;
    
    if (existing) {
        // class_addMethod doesn't have a instance vs class name. It must just use the signature of the method.
        class_addMethod(addToClass, newSel, imp, methodTypeEncoding);
        // Even though we just added a static method we need to use getInstance here....
        newMeth = class_getInstanceMethod(addToClass, newSel);
        
        Method orgMeth = class_getClassMethod(addToClass, makeLikeSel);
        method_exchangeImplementations(orgMeth, newMeth);
    }
    else
        class_addMethod(addToClass, makeLikeSel, imp, methodTypeEncoding);
    
    return existing;
}

// Make a category of the target class you are shadowing and call this
// Allow calling orignal implementation if done this way which injectStaticSelector does not support
void swizzleClassMethodWithCategoryImplementation(Class class, SEL original, SEL new) {
    Method originalMethod = class_getClassMethod(class, original);
    Method newMethod = class_getClassMethod(class, new);
    
    class = object_getClass((id)class);
    
    if (class_addMethod(class, original, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(class, new, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}
