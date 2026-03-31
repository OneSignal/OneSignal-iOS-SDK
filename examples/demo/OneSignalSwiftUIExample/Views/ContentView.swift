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

struct ContentView: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    headerBar
                    LogView(logManager: LogManager.shared)

                    ScrollView {
                        VStack(spacing: 0) {
                            AppInfoSection()
                            UserSection()
                            PushSection()
                            SendPushSection()
                            InAppMessagingSection()
                            SendInAppSection()
                            AliasesSection()
                            EmailsSection()
                            SMSSection()
                            TagsSection()
                            OutcomeEventsSection()
                            TriggersSection()
                            TrackEventSection()
                            LocationSection()
                            LiveActivitySection()
                            NextScreenSection()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
                .background(Color.osLightBackground)

                if viewModel.isLoading {
                    Color.black.opacity(0.54)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }

                if viewModel.showingAddSheet {
                    DialogOverlay {
                        AddItemDialog(
                            itemType: viewModel.addItemType,
                            onAdd: { key, value in viewModel.handleAddItem(key: key, value: value) },
                            onCancel: { viewModel.showingAddSheet = false }
                        )
                    }
                }

                if viewModel.showingMultiAddSheet {
                    DialogOverlay {
                        AddMultiItemDialog(
                            type: viewModel.multiAddType,
                            onAdd: { pairs in viewModel.handleMultiAdd(pairs: pairs) },
                            onCancel: { viewModel.showingMultiAddSheet = false }
                        )
                    }
                }

                if viewModel.showingRemoveMultiSheet {
                    DialogOverlay {
                        RemoveMultiDialog(
                            type: viewModel.removeMultiType,
                            items: viewModel.removeMultiItems,
                            onRemove: { keys in viewModel.handleRemoveMulti(keys: keys) },
                            onCancel: { viewModel.showingRemoveMultiSheet = false }
                        )
                    }
                }

                if viewModel.showingCustomNotificationSheet {
                    DialogOverlay {
                        CustomNotificationDialog(
                            onSend: { title, body in
                                viewModel.sendCustomNotification(title: title, body: body)
                                viewModel.showingCustomNotificationSheet = false
                            },
                            onCancel: { viewModel.showingCustomNotificationSheet = false }
                        )
                    }
                }

                if viewModel.showingTrackEventSheet {
                    DialogOverlay {
                        TrackEventDialog(
                            onTrack: { name, properties in
                                viewModel.trackEvent(name: name, properties: properties)
                                viewModel.showingTrackEventSheet = false
                            },
                            onCancel: { viewModel.showingTrackEventSheet = false }
                        )
                    }
                }

                if viewModel.showingOutcomeSheet {
                    DialogOverlay {
                        OutcomeDialog(
                            onSendNormal: { name in
                                viewModel.sendOutcome(name)
                                viewModel.showingOutcomeSheet = false
                            },
                            onSendUnique: { name in
                                viewModel.sendUniqueOutcome(name)
                                viewModel.showingOutcomeSheet = false
                            },
                            onSendWithValue: { name, value in
                                viewModel.sendOutcome(name, value: value)
                                viewModel.showingOutcomeSheet = false
                            },
                            onCancel: { viewModel.showingOutcomeSheet = false }
                        )
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .toast(message: $viewModel.toastMessage)
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            Spacer()
            Image("OneSignalLogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
            Text("iOS")
                .font(.system(size: 14))
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.osPrimary)
    }
}
