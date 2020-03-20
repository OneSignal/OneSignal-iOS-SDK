/**
* Modified MIT License
*
* Copyright 2020 OneSignal
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

#import "OSInAppMessageTag.h"
#import "OneSignalHelper.h"

@implementation OSInAppMessageTag

+ (instancetype)instanceWithData:(NSData *)data {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error || !json) {
        [OneSignal onesignal_Log:ONE_S_LL_ERROR message:[NSString stringWithFormat:@"Unable to decode in-app message tag JSON: %@", error.description ?: @"No Data"]];
        return nil;
    }
    
    return [self instanceWithJson:json];
}

+ (instancetype)instanceWithJson:(NSDictionary *)json {
    OSInAppMessageTag *tag = [OSInAppMessageTag new];

    //TODO: when backend is ready check that key matches
    if ([json[@"adds"] isKindOfClass:[NSDictionary class]]) {
        tag.tagsToAdd = json[@"adds"];
    } else {
        tag.tagsToAdd = nil;
    }
    //TODO: when backend is ready check that key matches
    if ([json[@"removes"] isKindOfClass:[NSArray class]]) {
        tag.tagsToRemove = json[@"removes"];
    } else {
        tag.tagsToRemove = nil;
    }
    
    return tag;
}

+ (instancetype _Nullable)instancePreviewFromPayload:(OSNotificationPayload * _Nonnull)payload {
    return nil;
}


- (NSDictionary *)jsonRepresentation {
    let json = [NSMutableDictionary new];
    
    if (_tagsToAdd)
        json[@"adds"] = _tagsToAdd;
    if (_tagsToRemove)
        json[@"removes"] = _tagsToRemove;

    return json;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"OSInAppMessageTag tagsToAdd: %@ \ntagsToRemove: %@", _tagsToAdd, _tagsToRemove];
}

@end
