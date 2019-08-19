/*
 * Copyright (C) 2019 HERE Europe B.V.
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
import UIKit

/*
 * This example app shows how to use an engine without a MapView. In this case we use the
 * TrafficEngine to query traffic incidents in Berlin, Germany.
 */
class ViewController: UIViewController {

    private var trafficEngine: TrafficEngine!

    override func viewDidLoad() {
        super.viewDidLoad()

        print("HERE SDK version: \(SDKBuildInformation.sdkVersion().versionName)")

        do {
            try trafficEngine = TrafficEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize traffic engine. Cause: \(engineInstantiationError)")
        }

        queryTrafficIncidents()
    }

    private func queryTrafficIncidents() {
        let incidentOptions = IncidentQueryOptions(impactFilter: [.minor, .major, .low, .critical],
                                                   categoryFilter: [IncidentCategory.construction, .accident, .congestion],
                                                   languageCode: LanguageCode.enUs)

        trafficEngine.queryForIncidents(in: GeoBoundingRect(southWestCorner: GeoCoordinates(latitude: 52.373556, longitude: 13.114358),
                                                            northEastCorner: GeoCoordinates(latitude: 52.611022, longitude: 13.479493)),
                                        options: incidentOptions) { (incidentQueryError, incidents) in

                                            if let error = incidentQueryError {
                                                self.showDialog(title: "Error", message: "Query for incidents failed. Cause: \(error)")
                                                return
                                            }

                                            for incident in incidents! {
                                                print("Incident: \(incident.category)"
                                                    + ", info: \(incident.description)"
                                                    + ", impact: \(incident.impact)")
                                            }

                                            self.showDialog(title: "Traffic Query Result", message: "\(incidents!.count) incident(s) found. See log for details.")
        }
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
