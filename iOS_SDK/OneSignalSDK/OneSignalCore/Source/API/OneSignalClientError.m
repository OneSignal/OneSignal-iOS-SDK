/**
 * Modified MIT License
 *
 * Copyright 2024 OneSignal
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

#import "OneSignalClientError.h"

@implementation OneSignalClientError

- (instancetype)initWithCode:(NSInteger)code message:(NSString* _Nonnull)message responseHeaders:(NSDictionary* _Nullable)headers response:(NSDictionary* _Nullable)response underlyingError:(NSError* _Nullable)error {
    _code = code;
    _message = message;
    _underlyingError = error;
    _response = response;
    _responseHeaders = headers;

    if (!error) {
        NSMutableDictionary *json = [NSMutableDictionary new];
        json[@"message"] = message;
        json[@"response"] = response;
        json[@"responseHeaders"] = headers;
        _underlyingError = [NSError errorWithDomain:@"OneSignalClientError" code:code userInfo:json];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<OneSignalClientError code: %ld, message: %@, response: %@, underlyingError: %@ >", (long)_code, _message, _response, _underlyingError];
}

@end
