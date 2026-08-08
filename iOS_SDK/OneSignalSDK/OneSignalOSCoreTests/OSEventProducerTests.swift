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
@testable import OneSignalOSCore

private class Handler {
    let name: String
    var fireCount = 0

    init(name: String) {
        self.name = name
    }
}

final class OSEventProducerTests: XCTestCase {

    func testFire_reachesEverySubscriber() {
        let producer = OSEventProducer<Handler>()
        let first = Handler(name: "first")
        let second = Handler(name: "second")

        producer.subscribe(first, key: "first")
        producer.subscribe(second, key: "second")
        producer.fire { $0.fireCount += 1 }

        XCTAssertEqual(first.fireCount, 1)
        XCTAssertEqual(second.fireCount, 1)
    }

    /// The reason for the keyed map: a store claiming a model's slot must not silence anyone else.
    func testSubscribe_underDistinctKeys_doesNotDisplaceExistingSubscriber() {
        let producer = OSEventProducer<Handler>()
        let store = Handler(name: "store")

        producer.subscribe(store, key: "store")
        producer.subscribe(Handler(name: "repo"), key: "repo")
        producer.fire { $0.fireCount += 1 }

        XCTAssertEqual(store.fireCount, 1)
    }

    func testSubscribe_underSameKey_replacesPreviousSubscriber() {
        let producer = OSEventProducer<Handler>()
        let replaced = Handler(name: "replaced")
        let replacement = Handler(name: "replacement")

        producer.subscribe(replaced, key: "shared")
        producer.subscribe(replacement, key: "shared")
        producer.fire { $0.fireCount += 1 }

        XCTAssertEqual(replaced.fireCount, 0)
        XCTAssertEqual(replacement.fireCount, 1)
    }

    func testUnsubscribe_stopsOnlyThatKey() {
        let producer = OSEventProducer<Handler>()
        let leaving = Handler(name: "leaving")
        let staying = Handler(name: "staying")

        producer.subscribe(leaving, key: "leaving")
        producer.subscribe(staying, key: "staying")
        producer.unsubscribe(leaving, key: "leaving")
        producer.fire { $0.fireCount += 1 }

        XCTAssertEqual(leaving.fireCount, 0)
        XCTAssertEqual(staying.fireCount, 1)
    }

    /// Handlers commonly react by re-entering the producer; holding the lock across callbacks
    /// would deadlock here.
    func testFire_allowsSubscriberToMutateSubscriptionsFromItsCallback() {
        let producer = OSEventProducer<Handler>()
        let reentrant = Handler(name: "reentrant")
        let added = Handler(name: "added")

        producer.subscribe(reentrant, key: "reentrant")
        producer.fire { handler in
            handler.fireCount += 1
            producer.subscribe(added, key: "added")
            producer.unsubscribe(handler, key: "reentrant")
        }

        XCTAssertEqual(reentrant.fireCount, 1)
        XCTAssertEqual(added.fireCount, 0, "A subscriber added mid-fire should not receive that fire")

        producer.fire { $0.fireCount += 1 }
        XCTAssertEqual(reentrant.fireCount, 1)
        XCTAssertEqual(added.fireCount, 1)
    }

    func testConcurrentSubscribeUnsubscribeAndFire_doesNotCrash() {
        let producer = OSEventProducer<Handler>()

        DispatchQueue.concurrentPerform(iterations: 1_000) { iteration in
            let key = "key-\(iteration % 8)"
            switch iteration % 3 {
            case 0:
                producer.subscribe(Handler(name: key), key: key)
            case 1:
                producer.unsubscribe(Handler(name: key), key: key)
            default:
                producer.fire { $0.fireCount += 1 }
            }
        }
    }
}
