/*
 Modified MIT License

 Copyright 2026 OneSignal

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
@testable import OneSignalOSCore
import XCTest

final class OSLogCrashAttributionTests: XCTestCase {
    func testIgnoresOneSignalSubstringOutsideModuleField() {
        XCTAssertFalse(
            isOneSignal([frame(appPath, symbol: "OneSignalNotificationCallback")])
        )
    }
    func testRecognizesKnownOneSignalModule() {
        XCTAssertTrue(isOneSignal([dynamicFrame("OneSignalNotifications")]))
    }
    func testRecognizesOneSignalKMPModule() {
        XCTAssertTrue(isOneSignal([dynamicFrame("OneSignalKMP")]))
    }
    func testRecognizesOneSignalCallbackBelowHostThrowingFrame() {
        XCTAssertTrue(
            isOneSignal([
                frame(appPath, symbol: "HostCallback"),
                dynamicFrame("OneSignalCore", symbol: "OneSignalCallback")
            ])
        )
    }
    func testRecognizesFoundationOriginatedOneSignalCrash() {
        XCTAssertTrue(
            isOneSignal([
                frame("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"),
                frame("/usr/lib/libobjc.A.dylib"),
                frame("/System/Library/Frameworks/Foundation.framework/Foundation"),
                dynamicFrame("OneSignalCore")
            ])
        )
    }
    func testRecognizesStaticFoundationOriginatedOneSignalCrash() {
        XCTAssertTrue(
            isOneSignal([
                frame("/System/Library/Frameworks/Foundation.framework/Foundation"),
                frame(appPath, symbol: "-[OneSignalUserDefaults saveCodeableDataForKey:withValue:]")
            ])
        )
    }
    func testRecognizesStaticSwiftOneSignalModule() {
        XCTAssertTrue(
            isOneSignal([
                frame(appPath, symbol: "_$s13OneSignalUser19OSPropertyOperationC7execute")
            ])
        )
    }
    func testRecognizesStaticKotlinOneSignalSymbol() {
        XCTAssertTrue(
            isOneSignal([
                frame(appPath, symbol: "kfun:com.onesignal.logger.LogCrashReporter.saveCrash")
            ])
        )
    }
    func testRecognizesStaticNotificationProcessingStack() {
        XCTAssertTrue(
            isOneSignal([
                frame(appPath, symbol: "finishProcessingNotification"),
                frame(appPath, symbol: "onesignal_Log")
            ])
        )
    }
    func testRecognizesStaticOSPrefixedObjCClass() {
        XCTAssertTrue(
            isOneSignal([
                frame(appPath, symbol: "-[OSNotificationsManager handleNotificationAction:]")
            ])
        )
        XCTAssertTrue(
            isOneSignal([frame(appPath, symbol: "+[OSMessagingController sharedInstance]")])
        )
    }
    func testRecognizesStaticSwizzledCategoryOnSystemClass() {
        XCTAssertTrue(
            isOneSignal([frame(appPath, symbol: "-[UIApplication setOneSignalDelegate:]")])
        )
        XCTAssertTrue(
            isOneSignal([
                frame(
                    appPath,
                    symbol: "-[UNUserNotificationCenter onesignalRequestAuthorizationWithOptions:"
                        + "completionHandler:]"
                )
            ])
        )
    }
    func testIgnoresUnrelatedObjCMethod() {
        XCTAssertFalse(
            isOneSignal([frame(appPath, symbol: "-[AppDelegate application:didFinishLaunching:]")])
        )
    }
    func testIgnoresGenericOSSymbol() {
        XCTAssertFalse(isOneSignal([frame(appPath, symbol: "OSPropertyOperationExecutor")]))
    }

    func testIgnoresOneSignalSymbolInSystemImage() {
        XCTAssertFalse(
            isOneSignal([frame("/usr/lib/libExample.dylib", symbol: "onesignal_Log")])
        )
    }

    func testSkipsSimulatorSystemImage() {
        XCTAssertTrue(
            isOneSignal([
                frame(
                    "/Library/Developer/CoreSimulator/Volumes/iOS/RuntimeRoot/"
                        + "System/Library/Frameworks/Foundation.framework/Foundation",
                    symbol: "onesignal_Log"
                ),
                dynamicFrame("OneSignalOSCore")
            ])
        )
    }

    func testIgnoresUnresolvedAndEmptyStacks() {
        XCTAssertFalse(
            isOneSignal([OSResolvedStackFrame(imagePath: nil, symbolName: "onesignal_Log")])
        )
        XCTAssertFalse(isOneSignal([]))
    }

    private let appPath = "/private/var/containers/Bundle/Application/App/ExampleApp"

    private func isOneSignal(_ frames: [OSResolvedStackFrame]) -> Bool {
        OSLogCrashHandler.isOneSignalAtFault(frames)
    }

    private func frame(_ imagePath: String, symbol: String? = nil) -> OSResolvedStackFrame {
        OSResolvedStackFrame(imagePath: imagePath, symbolName: symbol)
    }

    private func dynamicFrame(_ module: String, symbol: String? = nil) -> OSResolvedStackFrame {
        frame(
            "/private/var/containers/Bundle/Application/App/Frameworks/"
                + "\(module).framework/\(module)",
            symbol: symbol
        )
    }
}
