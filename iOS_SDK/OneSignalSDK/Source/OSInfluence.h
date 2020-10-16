/**
Modified MIT License

Copyright 2020 OneSignal

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

#import "OneSignal.h"

#ifndef OSInfluence_h
#define OSInfluence_h

@interface OSInfluenceBuilder : NSObject

@property (nonatomic) OSInfluenceChannel influenceChannel;
@property (nonatomic) OSSession influenceType;
@property (nonatomic, copy) NSArray * _Nullable ids;

@end

@interface OSInfluence : NSObject

@property (nonatomic, readonly) OSInfluenceChannel influenceChannel;
@property (nonatomic, readonly) OSSession influenceType;
@property (nonatomic, readwrite) NSArray * _Nullable ids;

- (id _Nonnull)initWithBuilder:(OSInfluenceBuilder * _Nonnull)builder;

- (OSInfluence * _Nonnull)copy;
- (BOOL)isAttributedInfluence;
- (BOOL)isDirectInfluence;
- (BOOL)isIndirectInfluence;
- (BOOL)isUnattributedInfluence;

@end

#endif /* OSInfluence_h */
