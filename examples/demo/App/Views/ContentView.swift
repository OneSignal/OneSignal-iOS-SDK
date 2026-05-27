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

import SwiftUI

/// Root view composing every section in the same order as the Capacitor demo.
struct ContentView: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @EnvironmentObject var toast: ToastPresenter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OS.Spacing.sectionGap) {
                    AppSection()
                    UserSection()
                    PushSection()
                    SendPushSection()
                    InAppSection()
                    SendIamSection()
                    AliasesSection()
                    EmailsSection()
                    SmsSection()
                    TagsSection()
                    OutcomesSection()
                    TriggersSection()
                    CustomEventsSection()
                    LocationSection()
                    LiveActivitySection()
                }
                .padding(.horizontal, OS.Spacing.pagePadding)
                .padding(.top, OS.Spacing.pagePadding)
                .padding(.bottom, OS.Spacing.sectionGap)
            }
            // `main_scroll_view` is anchored to the SwiftUI `ScrollView` (not
            // the inner `VStack`) so XCUITest exposes it as
            // `XCUIElementTypeScrollView` with the visible viewport's rect.
            // Anchoring on the inner `VStack` reported the full content rect
            // (multiple screens tall), causing WDIO `swipe` to compute
            // gesture coordinates outside the viewport — iOS clipped those
            // to the visible region and the swipe registered as a tap on
            // whatever button sat there (e.g. `send_sound_button`). The
            // ScrollView identifier is read by `waitForAppReady` and by
            // Android's `scrollIntoView` `scrollableElement` param.
            .accessibilityIdentifier("main_scroll_view")
            .background(OS.Color.lightBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OS.Color.primary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }
        }
        .osCenteredDialog(
            isPresented: Binding(
                get: { viewModel.activeTooltip != nil },
                set: { isPresented in if !isPresented { viewModel.dismissTooltip() } }
            )
        ) {
            if let tooltip = viewModel.activeTooltip {
                TooltipDialog(tooltip: tooltip, onClose: { viewModel.dismissTooltip() })
            }
        }
        .toast(message: $toast.message)
        // Auto-prompt for notification permission on first appear, matching the
        // Capacitor / Flutter / React Native demos (which all prompt from their
        // home screen's mount lifecycle). This races the OneSignal iOS-params
        // response: the standard alert shows before the SDK can register for
        // provisional authorization (which would otherwise silently grant
        // permission and skip the prompt entirely).
        .task {
            viewModel.promptPushPermission()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Image("onesignal_logo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 22)
                    .foregroundColor(.white)
                Text("iOS")
                    .font(OS.Font.bodyMedium)
                    .foregroundColor(.white)
            }
            .accessibilityIdentifier("brand_title")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(OneSignalViewModel())
        .environmentObject(ToastPresenter())
}
