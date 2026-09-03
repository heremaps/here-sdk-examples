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

/// Top bar displayed when a venue is loaded — shows venue name, back button, and topology toggle.
struct TopPanelView: View {
    @ObservedObject var indoorMapExample: IndoorMapExample

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Back button
                Button(action: {
                    indoorMapExample.deselectVenue()
                }) {
                    Image("back-button")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 30)
                }

                // Venue name label
                Text(indoorMapExample.selectedVenueName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0, green: 0.039, blue: 0.098).opacity(0.8))
                    .lineLimit(1)

                Spacer()

                // Topology icon - only shown if venue has topologies and routing is not active
                if indoorMapExample.hasTopologies &&
                    indoorMapExample.indoorRoutingViewModel.currentState != .routingUI &&
                    indoorMapExample.indoorRoutingViewModel.currentState != .showSpaceList {
                    Button(action: {
                        indoorMapExample.toggleTopology()
                    }) {
                        Image(indoorMapExample.topologyVisible ? "topology-focused" : "topology-default")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 41, height: 52)
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 60)
            .background(Color.white)

            Spacer()
        }
    }
}
