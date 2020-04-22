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

#import <Foundation/Foundation.h>
#import "OSOutcomeEventsV1Repository.h"
#import "Requests.h"
#import "OneSignalClient.h"
#import "OSOutcomeEvent.h"

@implementation OSOutcomeEventsV1Repository

- (void)requestMeasureOutcomeEventWithAppId:(NSString *)appId
                        deviceType:(NSNumber *)deviceType
                             event:(OSOutcomeEventParams *)event
                         onSuccess:(OSResultSuccessBlock)successBlock
                         onFailure:(OSFailureBlock)failureBlock {
    OSOutcomeEvent *outcome = [[OSOutcomeEvent alloc] initFromOutcomeEventParams:event];
    OneSignalRequest *request;
    switch (outcome.influenceType) {
        case DIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending direct outcome"];
            request = [OSRequestSendOutcomesV1ToServer directWithOutcome:outcome
                                                                 appId:appId
                                                            deviceType:deviceType];
            break;
        case INDIRECT:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending indirect outcome"];
            request = [OSRequestSendOutcomesV1ToServer indirectWithOutcome:outcome
                                                                   appId:appId
                                                              deviceType:deviceType];
            break;
        case UNATTRIBUTED:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Sending unattributed outcome"];
            request = [OSRequestSendOutcomesV1ToServer unattributedWithOutcome:outcome
                                                                       appId:appId
                                                                  deviceType:deviceType];
            break;
        case DISABLED:
        default:
            [OneSignal onesignal_Log:ONE_S_LL_VERBOSE message:@"Outcomes for current session are disabled"];
            return;
    }

    [OneSignalClient.sharedClient executeRequest:request onSuccess:successBlock onFailure:failureBlock];
}

@end
