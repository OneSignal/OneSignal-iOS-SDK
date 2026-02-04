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

/// Section for user login/logout and alias management
struct UserSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    
    var body: some View {
        // Login/Logout Section
        Section {
            // Login Button
            Button {
                viewModel.showAddSheet(for: .externalUserId)
            } label: {
                HStack {
                    Spacer()
                    Text("Login User")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            
            // Logout Button
            Button(role: .destructive) {
                viewModel.logout()
            } label: {
                HStack {
                    Spacer()
                    Text("Logout User")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .disabled(viewModel.externalUserId == nil)
            
            // Current User Info
            if let userId = viewModel.externalUserId {
                InfoRow(label: "External User ID", value: userId)
            }
        } header: {
            Text("User")
        }
        
        // Aliases Section
        Section {
            if viewModel.aliases.isEmpty {
                EmptyListRow(message: "No Aliases Added")
            } else {
                ForEach(viewModel.aliases) { alias in
                    KeyValueRow(item: alias) {
                        viewModel.removeAlias(alias)
                    }
                }
            }
            
            Button {
                viewModel.showAddSheet(for: .alias)
            } label: {
                HStack {
                    Spacer()
                    Label("Add Alias", systemImage: "plus")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        } header: {
            Text("Aliases")
        }
    }
}

#Preview {
    List {
        UserSection()
    }
    .environmentObject(OneSignalViewModel())
}
