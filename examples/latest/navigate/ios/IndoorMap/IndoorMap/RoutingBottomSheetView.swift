/*
 * Copyright (C) 2022-2026 HERE Europe B.V.
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

import SwiftUI

/// Bottom sheet overlay shown when the indoor routing UI is active (space selection, routing, space list).
struct RoutingBottomSheetView: View {
    @ObservedObject var indoorMapExample: IndoorMapExample

    var body: some View {
        VStack {
            Spacer()

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    // Drag handle
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(Color(.systemGray4))
                            .frame(width: 36, height: 5)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.height > 50,
                                   indoorMapExample.indoorRoutingViewModel.currentState == .showSpaceList {
                                    withAnimation(.spring()) {
                                        indoorMapExample.indoorRoutingViewModel.currentState = .routingUI
                                    }
                                }
                            }
                    )

                    if indoorMapExample.indoorRoutingViewModel.currentState == .spaceSelected {
                        SpaceSelectionView(viewModel: indoorMapExample.indoorRoutingViewModel)
                    } else if indoorMapExample.indoorRoutingViewModel.currentState == .routingUI {
                        IndoorRoutingView(
                            viewModel: indoorMapExample.indoorRoutingViewModel,
                            onDepartureTapped: {
                                indoorMapExample.indoorRoutingViewModel.showSpaceList(for: .selectingDeparture)
                            },
                            onArrivalTapped: {
                                indoorMapExample.indoorRoutingViewModel.showSpaceList(for: .selectingArrival)
                            }
                        )
                    } else if indoorMapExample.indoorRoutingViewModel.currentState == .showSpaceList {
                        RoutingSpaceListView(viewModel: indoorMapExample.indoorRoutingViewModel)
                    }
                }
                .frame(maxHeight: indoorMapExample.indoorRoutingViewModel.currentState == .showSpaceList
                       ? UIScreen.main.bounds.height
                       : nil)
                .background(Color.white)
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -5)

                // Close button positioned at top-right of the sheet (hidden for space list)
                if indoorMapExample.indoorRoutingViewModel.currentState != .showSpaceList {
                    Button(action: {
                        switch indoorMapExample.indoorRoutingViewModel.currentState {
                        case .spaceSelected:
                            indoorMapExample.indoorRoutingViewModel.closeSpaceSelection()
                        case .routingUI:
                            indoorMapExample.indoorRoutingViewModel.closeRoutingUI()
                        default:
                            break
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
            }
        }
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: indoorMapExample.indoorRoutingViewModel.currentState == .closed)
    }
}
