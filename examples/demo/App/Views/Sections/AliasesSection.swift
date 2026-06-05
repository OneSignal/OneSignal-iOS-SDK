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

struct AliasesSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var addOpen = false
    @State private var addMultipleOpen = false

    var body: some View {
        SectionCard(
            title: "ALIASES",
            sectionKey: "aliases",
            onInfoTap: { viewModel.showTooltip(for: "aliases") }
        ) {
            PairList(
                items: viewModel.aliases,
                emptyText: "No aliases added",
                sectionKey: "aliases"
            )

            ActionButton("ADD ALIAS", accessibilityID: "add_alias_button") {
                addOpen = true
            }
            ActionButton("ADD MULTIPLE ALIASES", accessibilityID: "add_multiple_aliases_button") {
                addMultipleOpen = true
            }
        }
        .osCenteredDialog(isPresented: $addOpen) {
            AddItemDialog(
                itemType: .alias,
                onAdd: { key, value in
                    viewModel.addAlias(label: key, id: value)
                    addOpen = false
                },
                onCancel: { addOpen = false }
            )
        }
        .osCenteredDialog(isPresented: $addMultipleOpen) {
            MultiPairInputDialog(
                type: .aliases,
                onAdd: { pairs in
                    viewModel.addAliases(pairs)
                    addMultipleOpen = false
                },
                onCancel: { addMultipleOpen = false }
            )
        }
    }
}
