/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

// This example shows how to query traffic info on incidents with the TrafficEngine.
class TrafficExample : TapDelegate {

    private let mapView: MapView
    private var trafficEngine: TrafficEngine
    // Visualizes traffic incidents found with the TrafficEngine.
    private var mapPolylineList = [MapPolyline]()
    private var tappedGeoCoordinates: GeoCoordinates = GeoCoordinates(latitude: -1, longitude: -1)


    init(_ mapView: MapView) {
        self.mapView = mapView

        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)

        do {
            // The traffic engine can be used to request additional information about
            // the current traffic situation anywhere on the road network.
            try trafficEngine = TrafficEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize TrafficEngine. Cause: \(engineInstantiationError)")
        }

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.liteDay, completion: onLoadScene)

        // Setting a tap handler to pick and search for traffic incidents around the tapped area.
        mapView.gestures.tapDelegate = self

        showDialog(title: "Note",
                   message: "Tap on the map to pick a traffic incident.")
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }

    func enableTrafficVisualization() {
        do {
            // Set the traffic flow refresh period to 5 * 60 seconds (5 minutes).
            // If MapFeatures.trafficFlow is disabled, no requests are made.
            //
            // Note: This code initiates periodic calls to the HERE Traffic backend. Depending on your contract,
            // each call may be charged separately. It is the application's responsibility to decide how
            // often this code should be executed.
            try MapContentSettings.setTrafficRefreshPeriod(5 * 60.0)
        } catch let error as MapContentSettings.TrafficRefreshPeriodError {
            print("TrafficRefreshPeriodError: \(error)")
        } catch {
            print("An unexpected error occurred: \(error)")
        }

        // Once these layers are added to the map, they will be automatically updated while panning the map.
        mapView.mapScene.enableFeatures([MapFeatures.trafficFlow : MapFeatureModes.trafficFlowWithFreeFlow])
        // MapFeatures.trafficIncidents renders traffic icons and lines to indicate the location of incidents.
        mapView.mapScene.enableFeatures([MapFeatures.trafficIncidents: MapFeatureModes.defaultMode])
    }

    func disableTrafficVisualization() {
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
        let sizeInPixels = Size2D(width: 50, height: 50)
        let rectangle = Rectangle2D(origin: originInPixels, size: sizeInPixels)
        // Creates a list of map content type from which the results will be picked.
        // The content type values can be mapContent, mapItems and customLayerData.
        var contentTypesToPickFrom = Array<MapScene.MapPickFilter.ContentType>();

        // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need traffic incidents so adding the mapContent filter.
        contentTypesToPickFrom.append(MapScene.MapPickFilter.ContentType.mapContent);
        let filter = MapScene.MapPickFilter(filter: contentTypesToPickFrom);
        mapView.pick(filter:filter,inside: rectangle, completion: onPickMapContent)
    }

    // MapViewBase.PickMapContentHandler to receive picked map content.
    func onPickMapContent(mapPickResults: MapPickResult?) {
        guard let mapPickResults = mapPickResults else {
            print("Pick operation failed.")
            return
        }
        guard let mapContentResult =  mapPickResults.mapContent else {
            print("Pick operation failed.")
            return
        }

        let trafficIncidents = mapContentResult.trafficIncidents
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
            let incidentLocation = trafficIncident!.location
            addTrafficIncidentsMapPolyline(geoPolyline: incidentLocation.polyline)

            // If the polyline contains any gaps, they are available as additionalPolylines.
            for additionalPolyline in incidentLocation.additionalPolylines {
                addTrafficIncidentsMapPolyline(geoPolyline: additionalPolyline)
            }
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
            var trafficIncidentPolylines: [GeoPolyline] = []

            // In case lengthInMeters == 0 then the polyline consists of two equal coordinates.
            // It is guaranteed that each incident has a valid polyline.
            trafficIncidentPolylines.append(trafficIncident.location.polyline)

            // If the polyline contains any gaps, they are available as additionalPolylines in TrafficLocation.
            trafficIncidentPolylines.append(contentsOf: trafficIncident.location.additionalPolylines)

            for polyline in trafficIncidentPolylines {
                for geoCoords in polyline.vertices {
                    let currentDistance = currentGeoCoords.distance(to: geoCoords)
                    if currentDistance < nearestDistance {
                        nearestDistance = currentDistance
                        nearestTrafficIncident = trafficIncident
                    }
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
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {

            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                // Handle OK button action.
                alert.dismiss(animated: true, completion: nil)
            }))

            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
}
