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

private struct LanguageOption: Identifiable {
    let name: String
    let code: String

    var id: String { code }
}

private let languageOptions = [
    LanguageOption(name: "Device Default", code: ""),
    LanguageOption(name: "English", code: "en"),
    LanguageOption(name: "Arabic", code: "ar"),
    LanguageOption(name: "Azerbaijani", code: "az"),
    LanguageOption(name: "Bosnian", code: "bs"),
    LanguageOption(name: "Catalan", code: "ca"),
    LanguageOption(name: "Chinese (Simplified)", code: "zh-Hans"),
    LanguageOption(name: "Chinese (Traditional)", code: "zh-Hant"),
    LanguageOption(name: "Croatian", code: "hr"),
    LanguageOption(name: "Czech", code: "cs"),
    LanguageOption(name: "Danish", code: "da"),
    LanguageOption(name: "Dutch", code: "nl"),
    LanguageOption(name: "Estonian", code: "et"),
    LanguageOption(name: "Finnish", code: "fi"),
    LanguageOption(name: "French", code: "fr"),
    LanguageOption(name: "Georgian", code: "ka"),
    LanguageOption(name: "Bulgarian", code: "bg"),
    LanguageOption(name: "German", code: "de"),
    LanguageOption(name: "Greek", code: "el"),
    LanguageOption(name: "Hindi", code: "hi"),
    LanguageOption(name: "Hebrew", code: "he"),
    LanguageOption(name: "Hungarian", code: "hu"),
    LanguageOption(name: "Indonesian", code: "id"),
    LanguageOption(name: "Italian", code: "it"),
    LanguageOption(name: "Japanese", code: "ja"),
    LanguageOption(name: "Korean", code: "ko"),
    LanguageOption(name: "Latvian", code: "lv"),
    LanguageOption(name: "Lithuanian", code: "lt"),
    LanguageOption(name: "Malay", code: "ms"),
    LanguageOption(name: "Norwegian", code: "nb"),
    LanguageOption(name: "Persian", code: "fa"),
    LanguageOption(name: "Polish", code: "pl"),
    LanguageOption(name: "Portuguese", code: "pt"),
    LanguageOption(name: "Punjabi", code: "pa"),
    LanguageOption(name: "Romanian", code: "ro"),
    LanguageOption(name: "Russian", code: "ru"),
    LanguageOption(name: "Serbian", code: "sr"),
    LanguageOption(name: "Slovak", code: "sk"),
    LanguageOption(name: "Spanish", code: "es"),
    LanguageOption(name: "Swedish", code: "sv"),
    LanguageOption(name: "Thai", code: "th"),
    LanguageOption(name: "Turkish", code: "tr"),
    LanguageOption(name: "Ukrainian", code: "uk"),
    LanguageOption(name: "Vietnamese", code: "vi")
]

/// Login/logout + status display, mirroring the Capacitor UserSection
struct UserSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var loginOpen = false

    var body: some View {
        SectionCard(title: "USER", sectionKey: "user") {
            VStack(spacing: 0) {
                InfoRow(
                    label: "Status",
                    value: viewModel.isLoggedIn ? "Logged In" : "Anonymous",
                    valueAccessibilityID: "user_status_value"
                )
                .padding(.vertical, 4)

                divider

                InfoRow(
                    label: "External ID",
                    value: viewModel.externalUserId ?? "—",
                    valueAccessibilityID: "user_external_id_value",
                    isMonospaced: true
                )
                .padding(.vertical, 4)

                divider

                languageMenu
                    .padding(.vertical, 4)
            }
            .osCard()

            ActionButton(
                viewModel.loginButtonTitle,
                accessibilityID: "login_user_button"
            ) {
                loginOpen = true
            }

            if viewModel.isLoggedIn {
                ActionButton(
                    "LOGOUT USER",
                    style: .outline,
                    accessibilityID: "logout_user_button"
                ) {
                    viewModel.logout()
                }
            }
        }
        .osCenteredDialog(isPresented: $loginOpen) {
            AddItemDialog(
                itemType: .externalUserId,
                onAdd: { _, value in
                    viewModel.login(externalId: value)
                    loginOpen = false
                },
                onCancel: { loginOpen = false }
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(OS.Color.divider)
            .frame(height: OS.Layout.dividerHeight)
            .padding(.vertical, 4)
    }

    private var languageMenu: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Language")
                .font(OS.Font.bodyMedium)
                .foregroundColor(OS.Color.bodyText)

            Spacer(minLength: 0)

            Menu {
                ForEach(languageOptions) { option in
                    Button {
                        viewModel.setLanguage(option.code)
                    } label: {
                        if option.code == viewModel.language {
                            Label(option.name, systemImage: "checkmark")
                        } else {
                            Text(option.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedLanguageName)
                        .font(OS.Font.bodySmall)
                        .foregroundColor(OS.Color.bodyText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(OS.Color.grey600)
                }
            }
            .accessibilityIdentifier("user_language_dropdown")
        }
    }

    private var selectedLanguageName: String {
        languageOptions.first { $0.code == viewModel.language }?.name ?? viewModel.language
    }
}
