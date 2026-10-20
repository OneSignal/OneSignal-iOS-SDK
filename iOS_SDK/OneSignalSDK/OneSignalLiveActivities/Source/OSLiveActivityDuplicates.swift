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

// Effectively blanks out this file for Mac Catalyst
#if targetEnvironment(macCatalyst)
#else
import OneSignalCore
import ActivityKit

/// Tests cannot create an `Activity`, so the helpers below take this protocol.
protocol OSLiveActivityInstance {
    var id: String { get }
    var oneSignalActivityId: String { get }
    var pushTokenString: String? { get }
    var isLive: Bool { get }
}

@available(iOS 16.1, *)
extension Activity: OSLiveActivityInstance where Attributes: OneSignalLiveActivityAttributes {
    var oneSignalActivityId: String { attributes.onesignal.activityId }
    var pushTokenString: String? { pushToken?.map { String(format: "%02x", $0) }.joined() }
    var isLive: Bool { activityState != .ended && activityState != .dismissed }
}

extension OneSignalLiveActivitiesManagerImpl {
    static func duplicateGroups<T: OSLiveActivityInstance>(_ activities: [T]) -> [String: [T]] {
        Dictionary(grouping: activities.filter { $0.isLive }, by: { $0.oneSignalActivityId }).filter { $0.value.count > 1 }
    }

    /// The backend sends updates to the cached update token, so we prefer the
    /// activity that has that token.
    static func activityToKeep<T: OSLiveActivityInstance>(_ group: [T], cachedUpdateToken: String?) -> T? {
        group.first { $0.pushTokenString != nil && $0.pushTokenString == cachedUpdateToken }
            ?? group.first { $0.pushTokenString != nil }
            ?? group.first
    }

    static func endDuplicates<T: OSLiveActivityInstance>(
        _ groups: [String: [T]],
        cachedUpdateToken: (String) async -> String?,
        end: (T) async -> Void
    ) async -> [T] {
        var kept = [T]()
        for (activityId, group) in groups {
            let cachedToken = await cachedUpdateToken(activityId)
            guard let keeper = activityToKeep(group, cachedUpdateToken: cachedToken) else {
                continue
            }
            kept.append(keeper)
            for duplicate in group where duplicate.id != keeper.id {
                await end(duplicate)
            }
        }
        return kept
    }

    @available(iOS 16.2, *)
    static func endDuplicateActivities<Attributes: OneSignalLiveActivityAttributes>(
        _ groups: [String: [Activity<Attributes>]],
        cachedUpdateToken: (String) async -> String?
    ) async -> [Activity<Attributes>] {
        await endDuplicates(groups, cachedUpdateToken: cachedUpdateToken) { duplicate in
            OneSignalLog.onesignalLog(.LL_DEBUG, message: "OneSignal.LiveActivities ending duplicate activity: \(Attributes.self):\(duplicate.oneSignalActivityId):\(duplicate.id)")
            await duplicate.end(nil, dismissalPolicy: ActivityUIDismissalPolicy.immediate)
        }
    }

    static func hasLiveDuplicate<T: OSLiveActivityInstance>(_ activity: T, in activities: [T]) -> Bool {
        activities.contains { $0.id != activity.id && $0.oneSignalActivityId == activity.oneSignalActivityId && $0.isLive }
    }
}
#endif
