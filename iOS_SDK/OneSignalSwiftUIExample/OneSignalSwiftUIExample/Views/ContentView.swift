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

/// Main content view composing all sections in the order matching the Android demo app
struct ContentView: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 0) {
                        // Collapsible log view at top
                        LogView(logManager: LogManager.shared)

                        // 1. App (includes consent, guidance banner)
                        AppInfoSection()

                        // 2. User (status, external ID, login/logout)
                        UserSection()

                        // 3. Push
                        PushSection()

                        // 4. Send Push Notification
                        SendPushSection()

                        // 5. In-App Messaging
                        InAppMessagingSection()

                        // 6. Send In-App Message
                        SendInAppSection()

                        // 7. Aliases
                        AliasesSection()

                        // 8. Emails
                        EmailsSection()

                        // 9. SMS
                        SMSSection()

                        // 10. Tags
                        TagsSection()

                        // 11. Outcome Events
                        OutcomeEventsSection()

                        // 12. Triggers
                        TriggersSection()

                        // 13. Track Event
                        TrackEventSection()

                        // 14. Location
                        LocationSection()

                        // 15. Next Activity
                        NextScreenSection()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .background(Color(.systemGroupedBackground))

                // Loading overlay
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .safeAreaInset(edge: .top) {
                // Compact header bar
                VStack(spacing: 0) {
                    Color.accentColor
                        .frame(height: UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .first?.statusBarManager?.statusBarFrame.height ?? 0)
                    HStack(spacing: 10) {
                        Image("OneSignalLogo")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 24)
                        Text("Sample App")
                            .font(.subheadline)
                            .opacity(0.9)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                }
                .ignoresSafeArea(edges: .top)
            }
            .navigationBarHidden(true)
            // Single add sheet
            .sheet(isPresented: $viewModel.showingAddSheet) {
                AddItemSheet(
                    itemType: viewModel.addItemType,
                    onAdd: { key, value in
                        viewModel.handleAddItem(key: key, value: value)
                    },
                    onCancel: {
                        viewModel.showingAddSheet = false
                    }
                )
            }
            // Multi-add sheet
            .sheet(isPresented: $viewModel.showingMultiAddSheet) {
                AddMultiItemSheet(
                    type: viewModel.multiAddType,
                    onAdd: { pairs in
                        viewModel.handleMultiAdd(pairs: pairs)
                    },
                    onCancel: {
                        viewModel.showingMultiAddSheet = false
                    }
                )
            }
            // Remove-multi sheet
            .sheet(isPresented: $viewModel.showingRemoveMultiSheet) {
                RemoveMultiSheet(
                    type: viewModel.removeMultiType,
                    items: viewModel.removeMultiItems,
                    onRemove: { keys in
                        viewModel.handleRemoveMulti(keys: keys)
                    },
                    onCancel: {
                        viewModel.showingRemoveMultiSheet = false
                    }
                )
            }
            // Custom notification sheet
            .sheet(isPresented: $viewModel.showingCustomNotificationSheet) {
                CustomNotificationSheet(
                    onSend: { title, body in
                        viewModel.sendCustomNotification(title: title, body: body)
                        viewModel.showingCustomNotificationSheet = false
                    },
                    onCancel: {
                        viewModel.showingCustomNotificationSheet = false
                    }
                )
            }
            // Track event sheet
            .sheet(isPresented: $viewModel.showingTrackEventSheet) {
                TrackEventSheet(
                    onTrack: { name, properties in
                        viewModel.trackEvent(name: name, properties: properties)
                        viewModel.showingTrackEventSheet = false
                    },
                    onCancel: {
                        viewModel.showingTrackEventSheet = false
                    }
                )
            }
        }
        .toast(message: $viewModel.toastMessage)
    }
}

#Preview {
    ContentView()
        .environmentObject(OneSignalViewModel())
}
