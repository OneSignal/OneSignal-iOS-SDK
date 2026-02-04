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

/// Section for user login/logout
struct UserSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            ActionButton(title: "Login User") {
                viewModel.showAddSheet(for: .externalUserId)
            }
            
            ActionButton(title: "Logout User") {
                viewModel.logout()
            }
        }
        .padding(.top, 12)
    }
}

/// Section for alias management
struct AliasesSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Aliases")
            
            CardContainer {
                if viewModel.aliases.isEmpty {
                    EmptyListRow(message: "No Aliases Added")
                } else {
                    ForEach(Array(viewModel.aliases.enumerated()), id: \.element.id) { index, alias in
                        if index > 0 {
                            CardDivider()
                        }
                        KeyValueRow(item: alias) {
                            viewModel.removeAlias(alias)
                        }
                    }
                }
            }
            
            ActionButton(title: "Add Alias") {
                viewModel.showAddSheet(for: .alias)
            }
            .padding(.top, 12)
        }
    }
}

#Preview {
    ScrollView {
        VStack {
            UserSection()
            AliasesSection()
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environmentObject(OneSignalViewModel())
}
