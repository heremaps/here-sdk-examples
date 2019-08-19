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

class TrafficExample: SetLayerStateCallback {

    private var viewController: UIViewController!
    private var mapView: MapView!
    private var trafficEngine: TrafficEngine!

    func onMapSceneLoaded(viewController: UIViewController, mapView: MapView) {
        self.mapView = mapView
        self.viewController = viewController
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
        camera.setZoomLevel(14)

        do {
            try trafficEngine = TrafficEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize traffic engine. Cause: \(engineInstantiationError)")
        }
    }

    func onEnableAllButtonClicked() {
        // By default, incidents are localized in EN_US
        // and all impacts and categories are enabled.
        let incidentQueryOptions = IncidentQueryOptions()
        logIncidentsInViewport(incidentQueryOptions: incidentQueryOptions)

        // Show real-time traffic lines on the map.
        enableTrafficFlow()
    }

    func onRoadWorksButtonClicked() {
        let incidentQueryOptions = IncidentQueryOptions(
            impactFilter: [IncidentImpact.minor],
            categoryFilter: [IncidentCategory.construction],
            languageCode: LanguageCode.enGb)

        logIncidentsInViewport(incidentQueryOptions: incidentQueryOptions)
    }

    func onDisableAllButtonClicked() {
        disableTrafficFlow()
    }

    private func enableTrafficFlow() {
        mapView.mapScene.setLayerState(layer: MapLayer.trafficFlow, newState: LayerState.enabled, callback: self)
    }

    private func disableTrafficFlow() {
        mapView.mapScene.setLayerState(layer: MapLayer.trafficFlow, newState: LayerState.disabled, callback: self)
    }

    // Conforming to SetLayerStateCallback protocol.
    func onSetLayerState(sceneError: SceneError?) {
        if let error = sceneError {
            print("Error when setting a new layer state: \(error)")
        }
    }

    private func logIncidentsInViewport(incidentQueryOptions: IncidentQueryOptions) {
        trafficEngine.queryForIncidents(in: mapView.camera.boundingRect,
                                        options: incidentQueryOptions) {
                                            (incidentQueryError, incidents) in

                if let error = incidentQueryError {
                    let message = "Query for incidents failed. Cause: \(error)"
                    self.showDialog(title: "Error", message: message)
                    return
                }

                for incident in incidents! {
                    print("Incident: \(incident.category)"
                        + ", info: \(incident.description)"
                        + ", impact: \(incident.impact)"
                        + ", from: \(String(describing: incident.startCoordinates))"
                        + " to: \(String(describing: incident.endCoordinates))")
                }

                self.showDialog(title: "Note", message: "\(incidents!.count) incident(s) found in viewport.")
        }
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
