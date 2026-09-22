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

import XCTest
import OneSignalCore
import OneSignalCoreMocks
import OneSignalOSCoreMocks
import OneSignalUserMocks
@testable import OneSignalOSCore
@testable import OneSignalUser

/// Listeners hear every line logged in the process, on the thread that logged it, so a test reads back
/// only the level and text it is about.
private final class LogCapture: NSObject, OSLogListener {
    private let lock = NSLock()
    private var entries: [(level: ONE_S_LOG_LEVEL, entry: String)] = []

    func onLogEvent(_ event: OneSignalLogEvent) {
        lock.withLock { entries.append((event.level, event.entry)) }
    }

    func entries(at level: ONE_S_LOG_LEVEL, mentioning text: String) -> [String] {
        return lock.withLock { entries.filter { $0.level == level && $0.entry.contains(text) }.map { $0.entry } }
    }
}

/**
 How the app is asked for a token: once per user per login, and audibly when a listener it registered is gone.
 */
final class UserJwtAskTests: XCTestCase {
    private var client = MockOneSignalClient()

    override func setUpWithError() throws {
        OneSignalCoreMocks.clearUserDefaults()
        OneSignalUserMocks.reset()
        OneSignalIdentifiers.currentAppId = "test-app-id"

        client = MockOneSignalClient()
        MockUserRequests.setDefaultCreateUserResponses(with: client, externalId: userA_EUID)
        OneSignalCoreImpl.setSharedClient(client)
    }

    override func tearDownWithError() throws {
        // The mock answers 50ms late, so a Request still in flight would otherwise land mid-next-test
        // and hydrate the shared models and JWT repo out from under it.
        OneSignalCoreMocks.waitUntil("A Request was still in flight at teardown") { self.clientIsIdle }
        OneSignalCoreMocks.clearUserDefaults()
    }

    private var clientIsIdle: Bool {
        return client.completedRequests.count == client.startedRequests.count
    }

    // MARK: - an ask nobody hears

    /// Before the app registers anything, an unheard ask is the cold-start order and the replay on
    /// registration covers it, so it stays below the default console level.
    func testAnAskBeforeAnyListenerIsRegisteredLogsAtDebug() {
        let log = LogCapture()
        OneSignalLog.debug().__add(log)
        defer { OneSignalLog.debug().__remove(log) }

        OSUserJwtInvalidatedListeners().notify(externalId: userA_EUID)

        let warnings = log.entries(at: .LL_WARN, mentioning: userA_EUID)
        XCTAssertTrue(warnings.isEmpty, "\(warnings)")
        XCTAssertEqual(log.entries(at: .LL_DEBUG, mentioning: userA_EUID).count, 1)
    }

    /// Listeners are held weakly, so one the app let go of leaves the ask unheard for good, and the ask
    /// is the only way the SDK gets a token, so that has to leave a trace above DEBUG.
    func testAnAskAfterTheListenerIsGoneWarns() {
        let log = LogCapture()
        OneSignalLog.debug().__add(log)
        defer { OneSignalLog.debug().__remove(log) }
        let listeners = OSUserJwtInvalidatedListeners()
        autoreleasepool {
            listeners.add(MockUserJwtInvalidatedListener())
        }

        listeners.notify(externalId: userA_EUID)

        let warnings = log.entries(at: .LL_WARN, mentioning: userA_EUID)
        XCTAssertEqual(warnings.count, 1, "\(warnings)")
        XCTAssertTrue(warnings.first?.contains("OSUserJwtInvalidatedListener") == true)
    }

    /// A heard ask is the normal path and stays quiet.
    func testAnAskWithAListenerIsDeliveredWithoutAWarning() {
        let log = LogCapture()
        OneSignalLog.debug().__add(log)
        defer { OneSignalLog.debug().__remove(log) }
        let listener = MockUserJwtInvalidatedListener()
        let listeners = OSUserJwtInvalidatedListeners()
        listeners.add(listener)

        listeners.notify(externalId: userA_EUID)

        OneSignalCoreMocks.waitUntil("The listener was not told") { listener.invalidatedExternalIds == [userA_EUID] }
        let warnings = log.entries(at: .LL_WARN, mentioning: userA_EUID)
        XCTAssertTrue(warnings.isEmpty, "\(warnings)")
    }

    // MARK: - asking again after a logout

    /// An ask left unanswered before a logout must not silence the next login as the same user: every
    /// login that builds a new Identity Model is asked afresh.
    func testLoggingInAgainAfterALogoutAsksAgain() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        // Held strongly for the test's lifetime: the observer keeps listeners weakly.
        let listener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(listener)
        defer { OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener) }

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("The first login did not ask") { listener.invalidatedExternalIds == [userA_EUID] }

        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)

        OneSignalCoreMocks.waitUntil("The second login did not ask again") {
            listener.invalidatedExternalIds == [userA_EUID, userA_EUID]
        }
    }

    /// A token the repo refuses answers nothing, so that login asks like one with no token.
    func testLoggingInAgainWithAnUnusableTokenAsksAgain() {
        OSCoreMocks.hydrateSharedJwtConfig(requiresUserAuth: true)
        let listener = MockUserJwtInvalidatedListener()
        OneSignalUserManagerImpl.sharedInstance.addUserJwtInvalidatedListener(listener)
        defer { OneSignalUserManagerImpl.sharedInstance.removeUserJwtInvalidatedListener(listener) }

        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: nil)
        OneSignalCoreMocks.waitUntil("The first login did not ask") { listener.invalidatedExternalIds == [userA_EUID] }

        OneSignalUserManagerImpl.sharedInstance.logout()
        OneSignalUserManagerImpl.sharedInstance.login(externalId: userA_EUID, token: "")

        OneSignalCoreMocks.waitUntil("The login with an empty token did not ask again") {
            listener.invalidatedExternalIds == [userA_EUID, userA_EUID]
        }
    }
}
