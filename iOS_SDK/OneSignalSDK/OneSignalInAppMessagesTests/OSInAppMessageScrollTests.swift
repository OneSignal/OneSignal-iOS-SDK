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

final class OSInAppMessageScrollTests: XCTestCase {
    private let visibleHeight: CGFloat = 400
    private let contentHeight: CGFloat = 700
    private var bottomOffset: CGFloat { contentHeight - visibleHeight }

    private func shouldDrag(offset: CGFloat,
                            contentHeight: CGFloat? = nil,
                            translation: CGFloat) -> Bool {
        OSInAppMessageScroll.shouldDragMessage(withContentOffsetY: offset,
                                               contentHeight: contentHeight ?? self.contentHeight,
                                               visibleHeight: visibleHeight,
                                               translationY: translation)
    }

    func testOverflow_requiresMoreThanOnePoint() {
        XCTAssertFalse(OSInAppMessageScroll.contentOverflows(withContentHeight: 400, visibleHeight: 400))
        XCTAssertFalse(OSInAppMessageScroll.contentOverflows(withContentHeight: 401, visibleHeight: 400))
        XCTAssertTrue(OSInAppMessageScroll.contentOverflows(withContentHeight: 401.5, visibleHeight: 400))
    }

    func testFittingContent_alwaysDrags() {
        XCTAssertTrue(shouldDrag(offset: 0, contentHeight: 400, translation: 20))
        XCTAssertTrue(shouldDrag(offset: 0, contentHeight: 400, translation: -20))
        XCTAssertTrue(shouldDrag(offset: 0, contentHeight: 400, translation: 0))
    }

    func testAtTop_dragsDownButScrollsUp() {
        XCTAssertTrue(shouldDrag(offset: 0, translation: 20))
        XCTAssertFalse(shouldDrag(offset: 0, translation: -20))
    }

    func testAtBottom_dragsUpButScrollsDown() {
        XCTAssertTrue(shouldDrag(offset: bottomOffset, translation: -20))
        XCTAssertFalse(shouldDrag(offset: bottomOffset, translation: 20))
    }

    func testMiddle_scrollsBothWays() {
        XCTAssertFalse(shouldDrag(offset: 150, translation: 20))
        XCTAssertFalse(shouldDrag(offset: 150, translation: -20))
    }

    func testNearEdgeWithinOnePoint_countsAsEdge() {
        XCTAssertTrue(shouldDrag(offset: 0.5, translation: 20))
        XCTAssertTrue(shouldDrag(offset: bottomOffset - 0.5, translation: -20))
    }

    func testNoVerticalMovement_scrollsWhenOverflowing() {
        XCTAssertFalse(shouldDrag(offset: 0, translation: 0))
    }

    private func isCapped(height: CGFloat, banner: Bool = false, fullscreen: Bool = false) -> Bool {
        OSInAppMessageScroll.isHeightCapped(withMessageHeight: height,
                                            availableHeight: visibleHeight,
                                            isBanner: banner,
                                            isFullscreen: fullscreen)
    }

    func testCenterModal_cappedOnlyWhenTallerThanAvailable() {
        XCTAssertFalse(isCapped(height: 300))
        XCTAssertFalse(isCapped(height: 401))
        XCTAssertTrue(isCapped(height: 600))
    }

    func testBanner_neverCapped() {
        XCTAssertFalse(isCapped(height: 600, banner: true))
    }

    func testFullscreen_alwaysCappedEvenWithoutHeight() {
        XCTAssertTrue(isCapped(height: 0, fullscreen: true))
    }
}
