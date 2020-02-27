/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

class TrafficExample {

    private var viewController: UIViewController
    private var mapView: MapViewLite
    private var trafficEngine: TrafficEngine

    init(viewController: UIViewController, mapView: MapViewLite) {
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

        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization()
    }

    func onRoadWorksButtonClicked() {
        let incidentQueryOptions = IncidentQueryOptions(
            impactFilter: [IncidentImpact.minor],
            categoryFilter: [IncidentCategory.construction],
            languageCode: LanguageCode.enGb)

        logIncidentsInViewport(incidentQueryOptions: incidentQueryOptions)
    }

    func onDisableAllButtonClicked() {
        disableTrafficVisualization()
    }

    private func enableTrafficVisualization() {
        do {
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficFlow, newState: LayerStateLite.enabled)
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficIncidents, newState: LayerStateLite.enabled)
        } catch let mapSceneError {
            print("Failed to enable traffic visualization. Cause: \(mapSceneError)")
        }
    }

    private func disableTrafficVisualization() {
        do {
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficFlow, newState: LayerStateLite.disabled)
            try mapView.mapScene.setLayerState(layer: MapLayerLite.trafficIncidents, newState: LayerStateLite.disabled)
        } catch let mapSceneError {
            print("Failed to disable traffic visualization. Cause: \(mapSceneError)")
        }
    }

    private func logIncidentsInViewport(incidentQueryOptions: IncidentQueryOptions) {
        trafficEngine.queryForIncidents(in: getMapViewGeoBox(),
                                        options: incidentQueryOptions) {
                                            (incidentQueryError, incidents) in

                if let error = incidentQueryError {
                    let message = "Query for incidents failed. Cause: \(error)"
                    self.showDialog(title: "Error", message: message)
                    return
                }

                // When incidentQueryError is nil, incidents is guaranteed to be not nil.
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

    private func getMapViewGeoBox() -> GeoBox {
        return mapView.camera.boundingRect
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
