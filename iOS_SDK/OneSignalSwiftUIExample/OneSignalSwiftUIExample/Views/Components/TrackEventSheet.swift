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

/// A dialog for tracking an event with an optional JSON properties string.
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
                // Title
                Text("Track Event")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("", text: $eventName)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: eventName) { _ in
                            nameError = nil
                        }
                    if let error = nameError {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Properties (optional, JSON)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("{\"ABC\":123}", text: $propertiesText)
                        .textFieldStyle(UnderlineTextFieldStyle())
                        .focused($focusedField, equals: .properties)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: propertiesText) { _ in
                            propertiesError = nil
                        }
                    if let error = propertiesError {
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 24) {
                    Spacer()

                    Button("CANCEL") {
                        onCancel()
                    }
                    .foregroundColor(.accentColor)

                    Button("TRACK") {
                        submitForm()
                    }
                    .foregroundColor(.accentColor)
                }
                .font(.system(size: 16, weight: .semibold))
            }
            .padding(24)
            .onAppear {
                focusedField = .name
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
                propertiesError = "Invalid JSON"
                return
            }
            properties = parsed
        }

        onTrack(trimmedName, properties)
    }
}

#Preview {
    TrackEventSheet(
        onTrack: { name, props in print("Track: \(name), \(String(describing: props))") },
        onCancel: { print("Cancel") }
    )
}
