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

struct TagsSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel
    @State private var addOpen = false
    @State private var addMultipleOpen = false
    @State private var removeOpen = false

    var body: some View {
        SectionCard(
            title: "TAGS",
            sectionKey: "tags",
            onInfoTap: { viewModel.showTooltip(for: "tags") }
        ) {
            PairList(
                items: viewModel.tags,
                emptyText: "No tags added",
                sectionKey: "tags",
                onRemove: { key in
                    if let item = viewModel.tags.first(where: { $0.key == key }) {
                        viewModel.removeTag(item)
                    }
                }
            )

            ActionButton("ADD TAG", accessibilityID: "add_tag_button") {
                addOpen = true
            }
            ActionButton("ADD MULTIPLE TAGS", accessibilityID: "add_multiple_tags_button") {
                addMultipleOpen = true
            }
            if !viewModel.tags.isEmpty {
                ActionButton(
                    "REMOVE TAGS",
                    style: .outline,
                    accessibilityID: "remove_tags_button"
                ) {
                    removeOpen = true
                }
            }
        }
        .osCenteredDialog(isPresented: $addOpen) {
            AddItemDialog(
                itemType: .tag,
                onAdd: { key, value in
                    viewModel.addTag(key: key, value: value)
                    addOpen = false
                },
                onCancel: { addOpen = false }
            )
        }
        .osCenteredDialog(isPresented: $addMultipleOpen) {
            MultiPairInputDialog(
                type: .tags,
                onAdd: { pairs in
                    viewModel.addTags(pairs)
                    addMultipleOpen = false
                },
                onCancel: { addMultipleOpen = false }
            )
        }
        .osCenteredDialog(isPresented: $removeOpen) {
            RemoveMultiDialog(
                type: .tags,
                items: viewModel.tags,
                onRemove: { keys in
                    viewModel.removeSelectedTags(keys)
                    removeOpen = false
                },
                onCancel: { removeOpen = false }
            )
        }
    }
}
