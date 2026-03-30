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
                Text("Custom Notification")
                    .font(.system(size: 24))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.46, green: 0.46, blue: 0.46))
                    TextField("", text: $titleText)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .title)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Body")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.46, green: 0.46, blue: 0.46))
                    TextField("", text: $bodyText)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .body)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                }

                Spacer()

                HStack(spacing: 8) {
                    Spacer()

                    Button("CANCEL") { onCancel() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    Button("SEND") { onSend(titleText, bodyText) }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isValid ? .accentColor : Color(red: 0.62, green: 0.62, blue: 0.62))
                        .disabled(!isValid)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .padding(24)
            .onAppear { focusedField = .title }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var isValid: Bool {
        !titleText.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
