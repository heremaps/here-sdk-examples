/*
 * Copyright (C) 2019-2026 HERE Europe B.V.
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
import Foundation

// Example usage of HERE EVSearchEngine for querying detailed EV charging location information.
// Requires an additional EVCP3 license that is not included with a standard Navigate license.
class EVSearchExample {
    private let searchEngine: EVSearchEngine?

    init() {
        do {
            self.searchEngine = try EVSearchEngine()
        } catch {
            print("EVSearchEngine instantiation failed: \(error)")
            self.searchEngine = nil
        }
    }

    func getSearchEngine() -> EVSearchEngine? {
        return searchEngine
    }

    // This standalone EVCP3 lookup is useful only when the caller already has HERE Place IDs.
    // EVRoutingExample uses SearchEngine.setEVInterface(...) for generic EV enrichment and this
    // direct lookup when it needs feature-gated EVCP3 fields such as tariffs and EVSE details.
    func runSearchExample(placeIds: [String]) {
        runSearchExample(placeIds: placeIds, completion: nil)
    }

    func runSearchExample(placeIds: [String],
                          completion: ((EVSearchError?, [EVChargingLocation]?) -> Void)?) {
        guard let searchEngine = searchEngine, !placeIds.isEmpty else {
            print("EVSearchEngine or placeIds is nil/empty")
            return
        }

        var options = EVSearchOptions()
        options.additionalFeatures = [
            .evses,
            .tariffs,
            .connectorGroups,
            .emsps,
            .locationInfo,
            .truckRestrictions
        ]
        searchEngine.setOptions(options: options)

        searchEngine.search(ids: placeIds) { error, results in
            completion?(error, results)

            if let searchError = error, searchError != .noResultsFound {
                print("EV search failed: \(searchError)")
                return
            }

            if error == .noResultsFound {
                print("EV search completed: No results found.")
            }

            guard let results = results else { return }
            for location in results {
                self.printLocation(location)
            }
        }
    }

    private func printLocation(_ location: EVChargingLocation) {
        print("=== EV Charging Location ===")
        if let operatorName = location.evChargingOperator?.name {
            print("Operator: \(operatorName)")
        }
        for evse in location.evses {
            print("EVSE ID: \(evse.id ?? "-")")
            for connector in evse.connectors {
                print(" - Connector: \(connector.id ?? "-")")
            }
        }
            let tariffs = location.tariffs
            print("Tariff count: \(tariffs.count) (requires tariffs plus evses or connectorGroups in EVSearchOptions)")
            for tariff in tariffs {
            print("Tariff: \(tariff.name ?? "-")")
        }
    }
}
