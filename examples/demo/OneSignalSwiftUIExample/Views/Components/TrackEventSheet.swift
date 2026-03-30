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

struct TrackEventSheet: View {
    let onTrack: (String, [String: Any]?) -> Void
    let onCancel: () -> Void

    @State private var eventName: String = ""
    @State private var propertiesText: String = ""
    @State private var nameError: String?
    @State private var propertiesError: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, properties
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Track Event")
                    .font(.system(size: 24))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Name")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.46, green: 0.46, blue: 0.46))
                    TextField("", text: $eventName)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: eventName) { _ in nameError = nil }
                    if let error = nameError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Properties (optional, JSON)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.46, green: 0.46, blue: 0.46))
                    TextField("{\"key\": \"value\"}", text: $propertiesText)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .properties)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: propertiesText) { _ in propertiesError = nil }
                    if let error = propertiesError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Spacer()

                    Button("CANCEL") { onCancel() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    Button("TRACK") { submitForm() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isTrackEnabled ? .accentColor : Color(red: 0.62, green: 0.62, blue: 0.62))
                        .disabled(!isTrackEnabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .padding(24)
            .onAppear { focusedField = .name }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var isTrackEnabled: Bool {
        let nameValid = !eventName.trimmingCharacters(in: .whitespaces).isEmpty
        let propsText = propertiesText.trimmingCharacters(in: .whitespaces)
        if propsText.isEmpty { return nameValid }
        let normalized = propsText
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        guard let data = normalized.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] != nil else {
            return false
        }
        return nameValid
    }

    private func submitForm() {
        let trimmedName = eventName.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty {
            nameError = "Required"
            return
        }

        var properties: [String: Any]?
        let trimmedProps = propertiesText.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
        if !trimmedProps.isEmpty {
            guard let data = trimmedProps.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                propertiesError = "Invalid JSON format"
                return
            }
            properties = parsed
        }

        onTrack(trimmedName, properties)
    }
}
