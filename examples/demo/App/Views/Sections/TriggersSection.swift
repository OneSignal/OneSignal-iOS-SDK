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

struct TriggersSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var addOpen = false
    @State private var addMultipleOpen = false
    @State private var removeOpen = false

    var body: some View {
        SectionCard(
            title: "TRIGGERS",
            sectionKey: "triggers",
            onInfoTap: { viewModel.showTooltip(for: "triggers") }
        ) {
            PairList(
                items: viewModel.triggers,
                emptyText: "No triggers added",
                sectionKey: "triggers",
                onRemove: { key in
                    if let item = viewModel.triggers.first(where: { $0.key == key }) {
                        viewModel.removeTrigger(item)
                    }
                }
            )

            ActionButton("ADD TRIGGER", accessibilityID: "add_trigger_button") {
                addOpen = true
            }
            ActionButton("ADD MULTIPLE TRIGGERS", accessibilityID: "add_multiple_triggers_button") {
                addMultipleOpen = true
            }
            if !viewModel.triggers.isEmpty {
                ActionButton(
                    "REMOVE TRIGGERS",
                    style: .outline,
                    accessibilityID: "remove_triggers_button"
                ) {
                    removeOpen = true
                }
                ActionButton(
                    "CLEAR ALL TRIGGERS",
                    style: .outline,
                    accessibilityID: "clear_triggers_button"
                ) {
                    viewModel.clearTriggers()
                }
            }
        }
        .osCenteredDialog(isPresented: $addOpen) {
            AddItemDialog(
                itemType: .trigger,
                onAdd: { key, value in
                    viewModel.addTrigger(key: key, value: value)
                    addOpen = false
                },
                onCancel: { addOpen = false }
            )
        }
        .osCenteredDialog(isPresented: $addMultipleOpen) {
            MultiPairInputDialog(
                type: .triggers,
                onAdd: { pairs in
                    viewModel.addTriggers(pairs)
                    addMultipleOpen = false
                },
                onCancel: { addMultipleOpen = false }
            )
        }
        .osCenteredDialog(isPresented: $removeOpen) {
            RemoveMultiDialog(
                type: .triggers,
                items: viewModel.triggers,
                onRemove: { keys in
                    viewModel.removeSelectedTriggers(keys)
                    removeOpen = false
                },
                onCancel: { removeOpen = false }
            )
        }
    }
}
