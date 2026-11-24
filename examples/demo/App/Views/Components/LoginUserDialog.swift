/**
 * Modified MIT License
 *
 * Copyright 2026 OneSignal
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

/// Login / switch-user dialog: external id required, JWT optional.
struct LoginUserDialog: View {
    let onLogin: (String, String?) -> Void
    let onCancel: () -> Void

    @State private var externalId: String = ""
    @State private var jwtToken: String = ""

    var body: some View {
        OSDialog(
            title: "Login User",
            confirmLabel: "Login",
            isConfirmEnabled: isValid,
            confirmAccessibilityID: "singleinput_confirm_button",
            cancelAccessibilityID: "singleinput_cancel_button",
            onConfirm: {
                let id = externalId.trimmingCharacters(in: .whitespacesAndNewlines)
                let token = jwtToken.trimmingCharacters(in: .whitespacesAndNewlines)
                onLogin(id, token.isEmpty ? nil : token)
            },
            onCancel: onCancel
        ) {
            VStack(spacing: 12) {
                OSTextField(
                    placeholder: "External User Id",
                    text: $externalId,
                    accessibilityID: "login_user_id_input"
                )
                OSTextField(
                    placeholder: "JWT Token (optional)",
                    text: $jwtToken,
                    accessibilityID: "login_user_jwt_input"
                )
            }
        }
    }

    private var isValid: Bool {
        !externalId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Update User JWT dialog. Fields are stacked full width like `LoginUserDialog` because a JWT
/// runs to several hundred characters. `initialExternalId` prefills the id and stays editable.
struct UpdateJwtDialog: View {
    let onUpdate: (String, String) -> Void
    let onCancel: () -> Void

    @State private var externalId: String
    @State private var jwtToken: String = ""

    init(
        initialExternalId: String,
        onUpdate: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onUpdate = onUpdate
        self.onCancel = onCancel
        _externalId = State(initialValue: initialExternalId)
    }

    var body: some View {
        OSDialog(
            title: "Update User JWT",
            confirmLabel: "Update",
            isConfirmEnabled: isValid,
            confirmAccessibilityID: "singlepair_confirm_button",
            cancelAccessibilityID: "singlepair_cancel_button",
            onConfirm: {
                onUpdate(
                    externalId.trimmingCharacters(in: .whitespacesAndNewlines),
                    jwtToken.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            },
            onCancel: onCancel
        ) {
            VStack(spacing: 12) {
                OSTextField(
                    placeholder: "External User Id",
                    text: $externalId,
                    accessibilityID: "update_jwt_external_id_input"
                )
                OSTextField(
                    placeholder: "JWT Token",
                    text: $jwtToken,
                    accessibilityID: "update_jwt_token_input"
                )
            }
        }
    }

    private var isValid: Bool {
        !externalId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !jwtToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
