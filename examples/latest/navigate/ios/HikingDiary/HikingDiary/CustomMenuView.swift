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

// Represents a single hiking diary entry with a title and description.
struct HikingDiaryEntry {
    let title: String
    let description: String
}

// Displays a single menu item in the list with swipe-to-delete functionality.
struct MenuItemView: View {
    var entry: HikingDiaryEntry
    var onDelete: () -> Void
    var onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 5)
        .contextMenu {
            Button(action: onTap) {
                Text("View Entry")
            }
            Button(role: .destructive, action: onDelete) {
                Text("Delete Entry")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .onLongPressGesture {
            onTap()
        }
        .onTapGesture {
            onTap()
        }
    }
}

/// View for displaying the menu. Each menu item triggers its respective action and supports swipeable delete.
struct MenuView: View {
    @ObservedObject var hikingDiary: HikingDiaryExample
    @State private var showMenu = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(hikingDiary.pastHikingDiaryEntries.indices, id: \.self) { index in
                    MenuItemView(
                        entry: hikingDiary.pastHikingDiaryEntries[index],
                        onDelete: {
                            hikingDiary.deletetHikeEntry(at: index)
                        },
                        onTap: {
                            hikingDiary.loadHikeEntry(index: index)
                            dismiss()
                        }
                    )
                }
            }
            .navigationBarItems(trailing: Button("Hiking Diary") {
                showMenu.toggle()
                
            })
            .navigationTitle("Past Hikes")
        }
    }
}

