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

/// Root view composing every section in the same order as the Capacitor demo
/// and wiring the modal sheets to the view-model state.
struct ContentView: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 4) {
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .accessibilityIdentifier("main_scroll_view")
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("OneSignal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $viewModel.showingAddSheet) {
            AddItemSheet(
                itemType: viewModel.addItemType,
                onAdd: { key, value in viewModel.handleAddItem(key: key, value: value) },
                onCancel: { viewModel.showingAddSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showingMultiAddSheet) {
            MultiPairInputSheet(
                type: viewModel.multiAddType,
                onAdd: { pairs in viewModel.handleMultiAdd(pairs) },
                onCancel: { viewModel.showingMultiAddSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showingRemoveMultiSheet) {
            RemoveMultiSheet(
                type: viewModel.removeMultiType,
                items: viewModel.removeMultiItems,
                onRemove: { keys in viewModel.handleRemoveMulti(keys) },
                onCancel: { viewModel.showingRemoveMultiSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showingOutcomeSheet) {
            OutcomeSheet(
                onSend: { name, mode, value in
                    switch mode {
                    case .normal:
                        viewModel.sendOutcome(name)
                    case .unique:
                        viewModel.sendUniqueOutcome(name)
                    case .value:
                        if let value = value {
                            viewModel.sendOutcome(name, value: value)
                        }
                    }
                    viewModel.showingOutcomeSheet = false
                },
                onCancel: { viewModel.showingOutcomeSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showingCustomNotificationSheet) {
            CustomNotificationSheet(
                onSend: { title, body in
                    viewModel.sendCustomNotification(title: title, body: body)
                    viewModel.showingCustomNotificationSheet = false
                },
                onCancel: { viewModel.showingCustomNotificationSheet = false }
            )
        }
        .sheet(isPresented: $viewModel.showingTrackEventSheet) {
            TrackEventSheet(
                onTrack: { name, properties in
                    viewModel.trackEvent(name: name, properties: properties)
                    viewModel.showingTrackEventSheet = false
                },
                onCancel: { viewModel.showingTrackEventSheet = false }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.activeTooltip != nil },
                set: { isPresented in if !isPresented { viewModel.dismissTooltip() } }
            )
        ) {
            if let tooltip = viewModel.activeTooltip {
                TooltipSheet(tooltip: tooltip, onClose: { viewModel.dismissTooltip() })
            }
        }
        .toast(message: $viewModel.toastMessage)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task {
                    await viewModel.fetchUserDataFromApi()
                    viewModel.refreshState()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .accessibilityIdentifier("refresh_button")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(OneSignalViewModel())
}
