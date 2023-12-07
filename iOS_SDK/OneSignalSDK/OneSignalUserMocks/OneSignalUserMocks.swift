/*
 Modified MIT License

 Copyright 2023 OneSignal

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

import Foundation
import OneSignalCoreMocks
@testable import OneSignalUser

@objc
public class OneSignalUserMocks : NSObject {
    static let mockCreateUserResponse: [String : Any] = [
        "httpStatusCode": 201,
        "identity": [
            "onesignal_id": "b7ef3218-fa05-4146-a793-9dc3d226f327"
        ],
        "properties": [
            "language": "en"
        ],
        "subscriptions": [
            [
                "app_id": "b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
                "id": "bb523026-ef0f-4157-a93a-6a6a7da15c28",
                "type": "iOSPush"
            ]
        ]
    ]
    
    static let mockFetchUserResponse: [String : Any] = [
        "httpStatusCode" : 200,
        "identity" : [
            "onesignal_id" : "b7ef3218-fa05-4146-a793-9dc3d226f327"
        ],
        "properties" : [
            "country" : "US",
            "first_active" : 1686953169,
            "ip" : "2603:8001:5c00:b9f6:a948:2692:1300:20ac",
            "language" : "en",
            "last_active" : 1686953174,
        ],
        "subscriptions": [
            "app_id" : "b2f7f966-d8cc-11e4-bed1-df8f05be55ba",
            // "app_version" : "1.4.4",
            "carrier" : "",
            "device_model" : "Simulator iPhone",
            "device_os" : "16.1",
            "enabled" : 1,
            "id" : "212c8e21-2271-4beb-a969-923892e246ae",
            "net_type" : 0,
            // "notification_types" : 80,
            "rooted" : 0,
            "sdk" : "050000-beta-04",
            "session_count" : 1,
            "session_time" : 0,
            "test_type" : 0,
            // "token" : "80e70242fa6e",
            "type" : "iOSPush"
        ]
    ]
    
    public static func setMockCreateUserResponse() {
        OneSignalCoreMocks.getClient().setMockResponseForRequest(request: String(describing: OSRequestCreateUser.self), response: mockCreateUserResponse)
    }
    
    public static func setMockFetchUserResponse(externalId: String?) {
    
        var response = mockFetchUserResponse
        
        if let externalId = externalId,
            var identity = response["identity"] as? [String : String] {
            identity["external_id"] = externalId
            response["identity"] = identity
        }
             
        OneSignalCoreMocks.getClient().setMockResponseForRequest(request: String(describing: OSRequestFetchUser.self), response: response)
    }
    
    public static func setMockIdentifyUserRequest(externalId: String) {
        let response = [
            "httpStatusCode" : 200,
            "identity" : [
                "external_id" : externalId,
                "onesignal_id" : "b7ef3218-fa05-4146-a793-9dc3d226f327"
            ]
        ] as [String : Any]
        
        OneSignalCoreMocks.getClient().setMockResponseForRequest(request: String(describing: OSRequestIdentifyUser.self), response: response)
    }
}
