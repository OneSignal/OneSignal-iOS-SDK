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

struct LiveActivitySection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var activityId: String = "order-1"
    @State private var orderNumber: String = "ORD-1234"

    private var isActivityIdEmpty: Bool {
        activityId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Live Activities", tooltipKey: "liveActivities")

            CardContainer {
                VStack(spacing: 0) {
                    HStack {
                        Text("Activity ID")
                            .font(.system(size: 14))
                        Spacer()
                        TextField("", text: $activityId)
                            .font(.system(size: 12, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)

                    CardDivider()

                    HStack {
                        Text("Order #")
                            .font(.system(size: 14))
                        Spacer()
                        TextField("", text: $orderNumber)
                            .font(.system(size: 12, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }

            ActionButton(title: "Start Live Activity") {
                viewModel.startLiveActivity(activityId: activityId, orderNumber: orderNumber)
            }
            .disabled(isActivityIdEmpty)
            .opacity(isActivityIdEmpty ? 0.5 : 1.0)
            .padding(.top, 12)

            ActionButton(title: viewModel.updateButtonLabel) {
                viewModel.updateLiveActivity(activityId: activityId)
            }
            .disabled(isActivityIdEmpty || viewModel.isUpdatingLiveActivity || !viewModel.hasApiKey || viewModel.isAtFinalStatus)
            .opacity(isActivityIdEmpty || viewModel.isUpdatingLiveActivity || !viewModel.hasApiKey || viewModel.isAtFinalStatus ? 0.5 : 1.0)
            .padding(.top, 8)

            OutlineActionButton(title: "Stop Updating Live Activity") {
                viewModel.stopUpdatingLiveActivity(activityId: activityId)
            }
            .disabled(isActivityIdEmpty)
            .opacity(isActivityIdEmpty ? 0.5 : 1.0)
            .padding(.top, 8)

            Button {
                viewModel.endLiveActivity(activityId: activityId)
            } label: {
                Text("End Live Activity")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.osPrimary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.osPrimary, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isActivityIdEmpty || !viewModel.hasApiKey)
            .opacity(isActivityIdEmpty || !viewModel.hasApiKey ? 0.5 : 1.0)
            .padding(.top, 8)
        }
    }
}
