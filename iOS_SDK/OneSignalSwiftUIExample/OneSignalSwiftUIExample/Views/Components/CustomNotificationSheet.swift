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

/// A dialog for entering a custom notification title and body.
struct CustomNotificationSheet: View {
    let onSend: (String, String) -> Void
    let onCancel: () -> Void

    @State private var titleText: String = ""
    @State private var bodyText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case title, body
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Title
                Text("Custom Notification")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Notification title", text: $titleText)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .title)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Body")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Notification body", text: $bodyText)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .body)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 24) {
                    Spacer()

                    Button("CANCEL") {
                        onCancel()
                    }
                    .foregroundColor(.accentColor)

                    Button("SEND") {
                        onSend(titleText, bodyText)
                    }
                    .foregroundColor(isValid ? .accentColor : .gray)
                    .disabled(!isValid)
                }
                .font(.system(size: 16, weight: .semibold))
            }
            .padding(24)
            .onAppear {
                focusedField = .title
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var isValid: Bool {
        !titleText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

#Preview {
    CustomNotificationSheet(
        onSend: { title, body in print("Send: \(title) - \(body)") },
        onCancel: { print("Cancel") }
    )
}
