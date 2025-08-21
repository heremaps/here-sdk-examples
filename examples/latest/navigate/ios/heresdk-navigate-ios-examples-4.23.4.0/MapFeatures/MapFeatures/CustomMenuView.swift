/*
 * Copyright (C) 2025 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

import heresdk
import SwiftUI

/// Represents a menu item in the menu view.
struct MenuItem {
    let title: String
    let onSelect: () -> Void
}

/// Represents a section in the menu view, which contains a list of menu items.
struct MenuSection {
    let title: String
    let items: [MenuItem]
}

/// View for displaying the menu. Each menu section and item triggers its respective action.
struct MenuView: View {
    var menuSections: [MenuSection]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(menuSections, id: \.title) { section in
                    Section(header: Text(section.title)) {
                        ForEach(section.items, id: \.title) { item in
                            Button(action: {
                                item.onSelect()
                                dismiss()
                            }) {
                                Text(item.title)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("MapFeatures Menu")
        }
    }
}
