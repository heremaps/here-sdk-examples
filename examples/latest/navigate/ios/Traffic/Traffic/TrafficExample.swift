/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

class TrafficExample: TapDelegate {

    private var viewController: UIViewController
    private var mapView: MapView
    private var trafficEngine: TrafficEngine
    // Visualizes traffic incidents found with the TrafficEngine.
    private var mapPolylineList = [MapPolyline]()
    private var tappedGeoCoordinates: GeoCoordinates = GeoCoordinates(latitude: -1, longitude: -1)

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)

        do {
            try trafficEngine = TrafficEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize TrafficEngine. Cause: \(engineInstantiationError)")
        }

        // Setting a tap handler to pick and search for traffic incidents around the tapped area.
        mapView.gestures.tapDelegate = self

        showDialog(title: "Note",
                   message: "Tap on the map to pick a traffic incident.")
    }

    func onEnableAllButtonClicked() {
        // Show real-time traffic lines and incidents on the map.
        enableTrafficVisualization()
    }

    func onDisableAllButtonClicked() {
        disableTrafficVisualization()
    }

    private func enableTrafficVisualization() {
        // Once these layers are added to the map, they will be automatically updated while panning the map.
        mapView.mapScene.enableFeatures([MapFeatures.trafficFlow : MapFeatureModes.trafficFlowWithFreeFlow])
        // MapFeatures.trafficIncidents renders traffic icons and lines to indicate the location of incidents.
        mapView.mapScene.enableFeatures([MapFeatures.trafficIncidents: MapFeatureModes.defaultMode])
    }

    private func disableTrafficVisualization() {
        mapView.mapScene.disableFeatures([MapFeatures.trafficFlow, MapFeatures.trafficIncidents])

        // This clears only the custom visualization for incidents found with the TrafficEngine.
        clearTrafficIncidentsMapPolylines()
    }

    // Conforming to TapDelegate protocol.
    func onTap(origin: Point2D) {
        // Can be nil when the map was tilted and the sky was tapped.
        if let touchGeoCoords = mapView.viewToGeoCoordinates(viewCoordinates: origin) {
            tappedGeoCoordinates = touchGeoCoords

            // Pick incidents that are shown in MapScene.Layers.trafficIncidents.
            pickTrafficIncident(touchPointInPixels: origin)

            // Query for incidents independent of MapScene.Layers.trafficIncidents.
            queryForIncidents(centerCoords: tappedGeoCoordinates)
        }
    }

    // Traffic incidents can only be picked, when MapScene.Layers.trafficIncidents is visible.
    func pickTrafficIncident(touchPointInPixels: Point2D) {
        let originInPixels = Point2D(x: touchPointInPixels.x, y: touchPointInPixels.y)
        let sizeInPixels = Size2D(width: 1, height: 1)
        let rectangle = Rectangle2D(origin: originInPixels, size: sizeInPixels)

        mapView.pickMapContent(inside: rectangle, completion: onPickMapContent)
    }

    // MapViewBase.PickMapContentHandler to receive picked map content.
    func onPickMapContent(mapContentResult: PickMapContentResult?) {
        if mapContentResult == nil {
            // An error occurred while performing the pick operation.
            return
        }

        let trafficIncidents = mapContentResult!.trafficIncidents
        if trafficIncidents.count == 0 {
            print("No traffic incident found at picked location")
        } else {
            print("Picked at least one incident.")
            let firstIncident = trafficIncidents.first!
            showDialog(title: "Traffic incident picked:", message: "Type: \(firstIncident.type.rawValue)")

            // Find more details by looking up the ID via TrafficEngine.
            findIncidentByID(firstIncident.originalId)
        }

        // Optionally, look for more map content like embedded POIs.
    }

    func findIncidentByID(_ originalId: String) {
        let trafficIncidentsLookupOptions = TrafficIncidentLookupOptions()
        // Optionally, specify a language:
        // the language of the country where the incident occurs is used.
        // trafficIncidentsLookupOptions.languageCode = LanguageCode.EN_US
        trafficEngine.lookupIncident(with: originalId,
                                     lookupOptions: trafficIncidentsLookupOptions,
                                     completion: onTrafficIncidentCompletion)
    }

    // TrafficIncidentCompletionHandler to receive traffic incidents from ID.
    func onTrafficIncidentCompletion(trafficQueryError: TrafficQueryError?, trafficIncident: TrafficIncident?) {
        if trafficQueryError == nil {
            print("Fetched TrafficIncident from lookup request." +
                    " Description: " + trafficIncident!.description.text)
            addTrafficIncidentsMapPolyline(geoPolyline: trafficIncident!.location.polyline)
        } else {
            showDialog(title: "TrafficLookupError:", message: trafficQueryError.debugDescription)
        }
    }

    private func addTrafficIncidentsMapPolyline(geoPolyline: GeoPolyline) {
        // Show traffic incident as polyline.
        let widthInPixels = 20.0
        let polylineColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        do {
            let mapPolyline =  try MapPolyline(geometry: geoPolyline,
                                               representation: MapPolyline.SolidRepresentation(
                                                lineWidth: MapMeasureDependentRenderSize(
                                                    sizeUnit: RenderSize.Unit.pixels,
                                                    size: widthInPixels),
                                                color: polylineColor,
                                                capShape: LineCap.round))
            
            mapView.mapScene.addMapPolyline(mapPolyline)
            mapPolylineList.append(mapPolyline)
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }
    }

    private func queryForIncidents(centerCoords: GeoCoordinates) {
        let geoCircle = GeoCircle(center: centerCoords, radiusInMeters: 1000)
        let trafficIncidentsQueryOptions = TrafficIncidentsQueryOptions()
        // Optionally, specify a language:
        // If the language is not supported, then the default behavior is applied and
        // the language of the country where the incident occurs is used.
        // trafficIncidentsQueryOptions.languageCode = LanguageCode.enUs
        trafficEngine.queryForIncidents(inside: geoCircle,
                                        queryOptions: trafficIncidentsQueryOptions,
                                        completion: onTrafficIncidentsFound)
    }

    // TrafficIncidentQueryCompletionHandler to receive traffic items.
    func onTrafficIncidentsFound(error: TrafficQueryError?,
                                 trafficIncidentsList: [TrafficIncident]?) {
        if let trafficQueryError = error {
            print("TrafficQueryError: \(trafficQueryError)")
            return
        }

        // If error is nil, it is guaranteed that the list will not be nil.
        var trafficMessage = "Found \(trafficIncidentsList!.count) result(s)."
        let nearestIncident = getNearestTrafficIncident(currentGeoCoords: tappedGeoCoordinates,
                                                        trafficIncidentsList: trafficIncidentsList!)
        trafficMessage.append(contentsOf: " Nearest incident: \(nearestIncident?.description.text ?? "nil")")
        print("Nearby traffic incidents: \(trafficMessage)")

        for trafficIncident in trafficIncidentsList! {
            print(trafficIncident.description.text)
            addTrafficIncidentsMapPolyline(geoPolyline: trafficIncident.location.polyline)
        }
    }

    private func getNearestTrafficIncident(currentGeoCoords: GeoCoordinates,
                                           trafficIncidentsList: [TrafficIncident]) -> TrafficIncident? {
        if trafficIncidentsList.count == 0 {
            return nil
        }

        // By default, traffic incidents results are not sorted by distance.
        var nearestDistance: Double = Double.infinity
        var nearestTrafficIncident: TrafficIncident!
        for trafficIncident in trafficIncidentsList {
            // In case lengthInMeters == 0 then the polyline consistes of two equal coordinates.
            // It is guaranteed that each incident has a valid polyline.
            for geoCoords in trafficIncident.location.polyline.vertices {
                let currentDistance = currentGeoCoords.distance(to: geoCoords)
                if currentDistance < nearestDistance {
                    nearestDistance = currentDistance
                    nearestTrafficIncident = trafficIncident
                }
            }
        }

        return nearestTrafficIncident
    }

    private func clearTrafficIncidentsMapPolylines() {
        for mapPolyline in mapPolylineList {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylineList.removeAll()
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
