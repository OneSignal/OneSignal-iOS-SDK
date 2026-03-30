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

struct UserSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "User")

            CardContainer {
                HStack {
                    Text("Status")
                        .font(.system(size: 14))
                    Spacer()
                    Text(viewModel.isLoggedIn ? "Logged In" : "Anonymous")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(viewModel.isLoggedIn ? .osSuccess : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

                CardDivider()

                HStack {
                    Text("External ID")
                        .font(.system(size: 14))
                    Spacer()
                    Text(viewModel.externalUserId ?? "\u{2013}")
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }

            ActionButton(title: viewModel.loginButtonTitle) {
                viewModel.showAddSheet(for: .externalUserId)
            }
            .padding(.top, 12)

            if viewModel.isLoggedIn {
                OutlineActionButton(title: "Logout User") {
                    viewModel.logout()
                }
                .padding(.top, 8)
            }
        }
    }
}

struct AliasesSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Aliases", tooltipKey: "aliases")

            CardContainer {
                if viewModel.aliases.isEmpty {
                    EmptyListRow(message: "No Aliases Added")
                } else {
                    ForEach(Array(viewModel.aliases.enumerated()), id: \.element.id) { index, alias in
                        if index > 0 { CardDivider() }
                        KeyValueRow(item: alias)
                    }
                }
            }

            ActionButton(title: "Add") {
                viewModel.showAddSheet(for: .alias)
            }
            .padding(.top, 12)

            ActionButton(title: "Add Multiple") {
                viewModel.showMultiAddSheet(for: .aliases)
            }
            .padding(.top, 8)
        }
    }
}
