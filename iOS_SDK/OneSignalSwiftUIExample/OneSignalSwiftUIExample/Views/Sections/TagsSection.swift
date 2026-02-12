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

/// Section for managing user tags with Add Tag, Add Tags (multi), and Remove Tags
struct TagsSection: View {
    @EnvironmentObject var viewModel: OneSignalViewModel

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: "Tags", tooltipKey: "tags")

            CardContainer {
                if viewModel.tags.isEmpty {
                    EmptyListRow(message: "No tags added")
                } else {
                    ForEach(Array(viewModel.tags.enumerated()), id: \.element.id) { index, tag in
                        if index > 0 {
                            CardDivider()
                        }
                        KeyValueRow(item: tag) {
                            viewModel.removeTag(tag)
                        }
                    }
                }
            }

            ActionButton(title: "Add") {
                viewModel.showAddSheet(for: .tag)
            }
            .padding(.top, 12)

            ActionButton(title: "Add Multiple") {
                viewModel.showMultiAddSheet(for: .tags)
            }
            .padding(.top, 8)

            // Remove Selected - only visible when tags exist
            if !viewModel.tags.isEmpty {
                OutlineActionButton(title: "Remove Selected") {
                    viewModel.showRemoveMultiSheet(for: .tags)
                }
                .padding(.top, 8)
            }
        }
    }
}

#Preview {
    TagsSection()
        .padding()
        .background(Color(.systemGroupedBackground))
        .environmentObject(OneSignalViewModel())
}
