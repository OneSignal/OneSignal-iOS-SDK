/**
Modified MIT License

Copyright 2021 OneSignal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. All copies of substantial portions of the Software may only be used in connection
with services provided by OneSignal.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#import <Foundation/Foundation.h>
#import "OSPlayerTags.h"
#import "OneSignalHelper.h"
#import "OneSignalUserDefaults.h"
#import "OneSignalCommonDefines.h"

@implementation OSPlayerTags

NSDictionary<NSString *, NSString *> *_tags;

-(id)init {
    self = [super init];
    if (self) {
        _tags = [NSMutableDictionary new];
        [self loadTagsFromUserDefaults];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dataDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    _tags, @"tags",
                                    nil];
    return dataDict;
}

- (NSDictionary *)allTags {
    return _tags;
}

- (NSString *)tagValueForKey:(NSString *)key {
    return _tags[key];
}

- (void)setTags:(NSDictionary *)tags {
    _tags = tags;
}

- (void)addTags:(NSDictionary *)tags {
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:_tags];
    for (NSString *key in tags.allKeys) {
        [newDict setValue:tags[key] forKey:key];
    }
    [self setTags:newDict];
}

- (void)deleteTags:(NSArray *)keys {
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:_tags];
    for (NSString *key in keys) {
        [newDict removeObjectForKey:key];
    }
    _tags = newDict;
}

- (void)addTagValue:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:_tags];
    newDict[key] = value;
    _tags = newDict;
}

- (void)loadTagsFromUserDefaults {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    _tags = [standardUserDefaults getSavedDictionaryForKey:OSUD_PLAYER_TAGS defaultValue:nil];
}

- (void)saveTagsToUserDefaults {
    let standardUserDefaults = OneSignalUserDefaults.initStandard;
    [standardUserDefaults saveDictionaryForKey:OSUD_PLAYER_TAGS withValue:_tags];
}

@end
