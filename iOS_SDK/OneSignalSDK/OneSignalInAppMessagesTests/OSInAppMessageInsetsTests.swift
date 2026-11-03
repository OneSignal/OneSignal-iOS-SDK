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

final class OSInAppMessageInsetsTests: XCTestCase {
    private let width: CGFloat = 800
    private let margin: CGFloat = 24
    // Landscape with a side safe area on each side, e.g. a camera housing on the left.
    private let safeArea = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 47)

    private func insets(margin: CGFloat? = nil,
                        safeArea: UIEdgeInsets? = nil,
                        regions: [CGRect] = [],
                        isFullscreen: Bool = false) -> UIEdgeInsets {
        OSInAppMessageInsets.horizontalInsets(withMargin: margin ?? self.margin,
                                              safeArea: safeArea ?? self.safeArea,
                                              width: width,
                                              regionFrames: regions.map { NSValue(cgRect: $0) },
                                              isFullscreen: isFullscreen)
    }

    func testNoRegions_usesSafeAreaWhenLargerThanMargin() {
        XCTAssertEqual(insets(), UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 47))
    }

    func testMarginAndSafeArea_takesMaxNotSum() {
        let result = insets(safeArea: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 30))
        XCTAssertEqual(result, UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 30))
    }

    func testNoSafeArea_usesMargin() {
        XCTAssertEqual(insets(safeArea: .zero), UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24))
    }

    func testNoWidthMargin_usesSafeAreaOnly() {
        let result = insets(margin: 0, safeArea: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0))
        XCTAssertEqual(result, UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0))
    }

    func testFullscreen_ignoresSafeAreaAndRegions() {
        let region = CGRect(x: 10, y: 100, width: 40, height: 80)
        XCTAssertEqual(insets(regions: [region], isFullscreen: true),
                       UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24))
        XCTAssertEqual(insets(margin: 0, regions: [region], isFullscreen: true), .zero)
    }

    func testRegionInsideLeftSafeArea_addsClearance() {
        let region = CGRect(x: 10, y: 100, width: 40, height: 80)
        XCTAssertEqual(insets(regions: [region]), UIEdgeInsets(top: 0, left: 74, bottom: 0, right: 47))
    }

    func testRegionInsideRightSafeArea_addsClearance() {
        let region = CGRect(x: 760, y: 100, width: 30, height: 80)
        XCTAssertEqual(insets(regions: [region]), UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 64))
    }

    func testRegionsOnBothSides_addClearanceToEach() {
        let left = CGRect(x: 10, y: 100, width: 40, height: 80)
        let right = CGRect(x: 760, y: 100, width: 30, height: 80)
        XCTAssertEqual(insets(regions: [left, right]), UIEdgeInsets(top: 0, left: 74, bottom: 0, right: 64))
    }

    func testRegionClearanceSmallerThanSafeArea_keepsSafeArea() {
        let region = CGRect(x: 2, y: 100, width: 20, height: 80)
        XCTAssertEqual(insets(regions: [region]), UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 47))
    }

    func testRegionFlushWithEdge_isIgnored() {
        let left = CGRect(x: 0, y: 0, width: 59, height: 400)
        let right = CGRect(x: 753, y: 0, width: 47, height: 400)
        XCTAssertEqual(insets(regions: [left, right]), UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 47))
    }

    func testRegionStraddlingSafeAreaEdge_isIgnored() {
        let left = CGRect(x: 40, y: 100, width: 40, height: 80)
        let right = CGRect(x: 740, y: 100, width: 40, height: 80)
        XCTAssertEqual(insets(regions: [left, right]), UIEdgeInsets(top: 0, left: 59, bottom: 0, right: 47))
    }

    func testRegionWithinOnePointOfSafeAreaEdge_addsClearance() {
        let region = CGRect(x: 10, y: 100, width: 50, height: 80)
        XCTAssertEqual(insets(regions: [region]).left, 84)
    }
}
