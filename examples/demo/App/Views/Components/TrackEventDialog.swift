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

/// Centered dialog that captures an event name plus an optional
/// JSON properties payload.
struct TrackEventDialog: View {
    let onTrack: (String, [String: Any]?) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var propertiesText: String = ""
    @State private var error: String?

    var body: some View {
        OSDialog(
            title: "Track Event",
            confirmLabel: "Track",
            isConfirmEnabled: isValid,
            confirmAccessibilityID: "event_track_button",
            cancelAccessibilityID: "event_cancel_button",
            onConfirm: submit,
            onCancel: onCancel
        ) {
            VStack(alignment: .leading, spacing: 12) {
                OSTextField(
                    placeholder: "Event Name",
                    text: $name,
                    accessibilityID: "event_name_input"
                )

                Text("Properties (JSON, optional)")
                    .font(OS.Font.bodySmall)
                    .foregroundColor(OS.Color.grey600)

                OSTextEditor(
                    placeholder: "{ \"key\": \"value\" }",
                    text: $propertiesText,
                    minHeight: 120,
                    accessibilityID: "event_properties_input"
                )

                if let error = error {
                    Text(error)
                        .font(OS.Font.bodySmall)
                        .foregroundColor(OS.Color.primary)
                        .accessibilityIdentifier("event_properties_error")
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedProps = propertiesText.trimmingCharacters(in: .whitespaces)

        if trimmedProps.isEmpty {
            onTrack(trimmedName, nil)
            return
        }

        guard let data = trimmedProps.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            error = "Properties must be valid JSON"
            return
        }
        guard let dict = json as? [String: Any] else {
            error = "Properties must be a JSON object"
            return
        }
        error = nil
        onTrack(trimmedName, dict)
    }
}
