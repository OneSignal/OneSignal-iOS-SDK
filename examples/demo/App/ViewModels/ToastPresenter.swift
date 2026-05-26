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

import Foundation
import Combine

/// UI-layer toast presenter per sdk-shared/demo/build.md Prompt 7.6.
/// Feedback messages are owned by the UI layer (injected as an
/// `@EnvironmentObject`), never by `OneSignalViewModel`. Replace-on-show:
/// dismisses any visible toast and resets the [toastDurationMs] timer on
/// every call.
@MainActor
final class ToastPresenter: ObservableObject {

    static let toastDurationMs: UInt64 = 3_000

    @Published var message: String?

    private var dismissTask: Task<Void, Never>?

    func show(_ message: String) {
        dismissTask?.cancel()
        self.message = message
        let target = message
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: ToastPresenter.toastDurationMs * 1_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.message == target { self.message = nil }
        }
    }
}
