/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
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

/// Represents a single row of topology accessibility info (a group of transport mode icons + directionality).
struct TopologyAccessRow: Identifiable {
    let id = UUID()
    let iconNames: [String]
    let directionLabel: String
}

/// Bottom drawer view displaying topology details when a topology is tapped on the map.
/// Shows the topology identifier as a bold title, followed by rows of transport mode icons
/// grouped by directionality (matching the UIKit implementation).
struct TopologyDetailsView: View {
    let topology: VenueTopology

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Topology identifier (bold title)
            Text("\(topology.identifier)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .padding(.horizontal, 20)

            // Accessibility rows - use fixed-width icon column so text aligns across rows
            ForEach(buildAccessibilityRows()) { row in
                HStack(spacing: 0) {
                    // Fixed-width area for transport mode icons
                    HStack(spacing: 4) {
                        ForEach(row.iconNames, id: \.self) { iconName in
                            Image(iconName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .frame(width: 150, alignment: .leading)

                    // Directionality label - all rows start text at same x position
                    Text(row.directionLabel)
                        .font(.system(size: 14))
                        .foregroundColor(Color(.systemGray))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }

            Spacer()
                .frame(height: 36)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -5)
    }

    /// Builds the accessibility rows from the topology data, matching UIKit's getTopologyInfo logic.
    /// Pedestrian mode gets its own row; all other vehicle modes sharing the same directionality
    /// are grouped together in a single row.
    private func buildAccessibilityRows() -> [TopologyAccessRow] {
        var rows = [TopologyAccessRow]()
        var pedestrianRow: TopologyAccessRow?
        var vehicleGroups = [String: [String]]() // directionLabel -> [iconNames]

        for access in topology.accessibility {
            let mode = access.mode
            let directionLabel = directionString(for: access.direction)
            let iconName: String

            switch mode {
            case .pedestrian:
                iconName = "img_pedestrian"
                pedestrianRow = TopologyAccessRow(iconNames: [iconName], directionLabel: directionLabel)
                continue
            case .car:
                iconName = "img_car"
            case .taxi:
                iconName = "img_taxi"
            case .scooter:
                iconName = "img_bike"
            default:
                continue
            }

            if vehicleGroups[directionLabel] == nil {
                vehicleGroups[directionLabel] = []
            }
            vehicleGroups[directionLabel]?.append(iconName)
        }

        // Pedestrian row first (matching UIKit order)
        if let pedestrian = pedestrianRow {
            rows.append(pedestrian)
        }

        // Vehicle group rows
        for (directionLabel, iconNames) in vehicleGroups {
            rows.append(TopologyAccessRow(iconNames: iconNames, directionLabel: directionLabel))
        }

        return rows
    }

    /// Converts a TopologyDirectionality enum value to a display string.
    private func directionString(for direction: VenueTopology.TopologyDirectionality) -> String {
        switch direction {
        case .toStart:
            return "TO_START"
        case .fromStart:
            return "FROM_START"
        case .bidirectional:
            return "BIDIRECTIONAL"
        case .undefined:
            return "UNDEFINED"
        @unknown default:
            return "UNDEFINED"
        }
    }
}
