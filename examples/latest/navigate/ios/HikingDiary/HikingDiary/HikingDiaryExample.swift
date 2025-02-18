/*
 * Copyright (C) 2022-2025 HERE Europe B.V.
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

enum ConstantsEnum {
    static let DEFAULT_MAP_CENTER = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
    static let DEFAULT_DISTANCE_IN_METERS: Double = 1000 * 2
}

// An app that tracks the user's location and allows to record the travelled path with a GPXTrackWriter.
class HikingDiaryExample: LocationDelegate,
                          ObservableObject {

    // A class to receive location events from the device.
    private let herePositioningProvider = HEREPositioningProvider()

    private let mapView: MapView
    private var myPathMapPolyline: MapPolyline?
    private var isHiking = false
    private var isGPXTrackLoaded = false
    private var gpxTrackWriter = GPXTrackWriter()
    private let gpxManager: GPXManager
    private let positioningVisualizer: HEREPositioningVisualizer
    private let outdoorRasterLayer: OutdoorRasterLayer
    private var locationFilter: LocationFilterStrategy
    var textViewUpdateDelegate: TextViewUpdateDelegate?
    @Published var pastHikingDiaryEntries: [HikingDiaryEntry] = []

    init(_ mapView: MapView) {
        self.mapView = mapView
        
        // A class to filter out undesired location signals.
        locationFilter = DistanceAccuracyLocationFilter()

        // A class to manage GPX operations.
        gpxManager = GPXManager(gpxDocumentFileName: "myGPXDocument.gpx")

        // A helper to show our current location and the raw location signals.
        positioningVisualizer = HEREPositioningVisualizer(mapView)

        // On top of the default map style, we allow to show a dedicated outdoor layer.
        outdoorRasterLayer = OutdoorRasterLayer(mapView: mapView)

        // Sets delegate to receive locations from HERE Positioning.
        herePositioningProvider.startLocating(locationDelegate: self, accuracy: .navigation)

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        animateCameraToCurrentLocation()
        
        // Load the past hike trips to this published variable used for displaying and deleting those entries.
        pastHikingDiaryEntries = getPastHikingDiaryEntries()
        
        let message = "For this example app, an outdoor layer from thunderforest.com is used. Without setting a valid API key, these raster tiles will show a watermark (terms of usage: https://www.thunderforest.com/terms/).\n Attribution for the outdoor layer: \n Maps © www.thunderforest.com, \n Data © www.osm.org/copyright."
        showDialog(title: "Note", message: message)
        
        updateMessage("** Hiking Diary **")
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        
        // Enhance the scene with map features suitable for hiking trips.
        mapView.mapScene.enableFeatures([MapFeatures.terrain : MapFeatureModes.terrain3d])
        mapView.mapScene.enableFeatures([MapFeatures.ambientOcclusion : MapFeatureModes.ambientOcclusionAll])
        mapView.mapScene.enableFeatures([MapFeatures.buildingFootprints : MapFeatureModes.buildingFootprintsAll])
        mapView.mapScene.enableFeatures([MapFeatures.contours : MapFeatureModes.contoursAll])
        mapView.mapScene.enableFeatures([MapFeatures.extrudedBuildings : MapFeatureModes.extrudedBuildingsAll])
        mapView.mapScene.enableFeatures([MapFeatures.landmarks : MapFeatureModes.landmarksTextured])
        
    }

    func onStartHikingButtonClicked() {
        clearMap()
        isHiking = true
        isGPXTrackLoaded = false
        animateCameraToCurrentLocation()
        updateMessage("Starting Hike.")

        // Create a new GPXTrackWriter to record this trip.
        gpxTrackWriter = GPXTrackWriter()
    }

    func onStopHikingButtonClicked() {
        clearMap()

        if isHiking && isGPXTrackLoaded == false {
            saveDiaryEntry()
        } else {
            updateMessage("Stopped.")
        }

        isHiking = false
    }

    func enableOutdoorRasterLayer() {
        outdoorRasterLayer.enable()
    }

    func disableOutdoorRasterLayer() {
        outdoorRasterLayer.disable()
    }

    // Conform to LocationDelegate protocol.
    func onLocationUpdated(_ location: heresdk.Location) {
        positioningVisualizer.updateLocationIndicator(location)

        if isHiking {
            // Here we visualize all incoming locations, unfiltered.
            positioningVisualizer.renderUnfilteredLocationSignals(location)
        }

        if isHiking && locationFilter.checkIfLocationCanBeUsed(location) {
            // Here we store only locations that are considered to be accurate enough.
            gpxTrackWriter.onLocationUpdated(location)

            // Visualize our hiking trip as an expanding polyline.
            let mapPolyline = updateTravelledPath()

            // Calculate the currently travelled distance.
            if let mapPolyline = mapPolyline {
                let distanceTravelled = getLengthOfGeoPolylineInMeters(mapPolyline.geometry)
                updateMessage("Hike Distance: \(distanceTravelled) m")
            }
        }
    }

    private func updateTravelledPath() -> MapPolyline? {
        let geoCoordinatesList = gpxManager.getGeoCoordinatesList(track: gpxTrackWriter.track)

        if geoCoordinatesList.count < 2 {
            return nil
        }

        // We are sure that the number of vertices is greater than 1 (see above), so it will not crash.
        let geoPolyline = try! GeoPolyline(vertices: geoCoordinatesList)

        // Add polyline to the map, if instance is nil.
        guard let mapPolyline = myPathMapPolyline else {
            addMapPolyline(geoPolyline)
            return myPathMapPolyline
        }

        // Update the polyline shape that shows the travelled path of the user.
        mapPolyline.geometry = geoPolyline

        return mapPolyline
    }

    private func getLengthOfGeoPolylineInMeters(_ geoPolyLine: GeoPolyline) -> Int {
        var length = 0
        for i in 1...geoPolyLine.vertices.count - 1 {
            length =  length + Int(geoPolyLine.vertices[i].distance(to: geoPolyLine.vertices[i-1]))
        }
        return length
    }

    private func addMapPolyline(_ geoPolyline: GeoPolyline) {
        clearMap()
        let widthInPixels = 20.0
        let polylineColor = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.63)
        do {
            myPathMapPolyline =  try MapPolyline(geometry: geoPolyline,
                                                    representation: MapPolyline.SolidRepresentation(
                                                        lineWidth: MapMeasureDependentRenderSize(
                                                            sizeUnit: RenderSize.Unit.pixels,
                                                            size: widthInPixels),
                                                        color: polylineColor,
                                                        capShape: LineCap.round))

            mapView.mapScene.addMapPolyline(myPathMapPolyline!)
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }
    }

    private func clearMap() {
        if myPathMapPolyline != nil {
            mapView.mapScene.removeMapPolyline(myPathMapPolyline!)
            myPathMapPolyline = nil
        }
        positioningVisualizer.clearMap()
    }

    private func saveDiaryEntry() {
        // Permanently store the trip on the device.
        let result = gpxManager.saveGPXTrack(gpxTrackWriter.track)
        pastHikingDiaryEntries.append(HikingDiaryEntry(title: gpxTrackWriter.track.name, description: gpxTrackWriter.track.description))
        updateMessage("Saved Hike: \(result).")
    }

    // Load the selected diary entry and show the polyline related to that hike.
    private func loadDiaryEntry(index: Int) {
        if isHiking {
            print("Stop hiking first.")
            return
        }

        isGPXTrackLoaded = true

        // Load the hiking trip.
        guard let gpxTrack = gpxManager.getGPXTrack(index: index) else {
            return
        }

        let diaryGeoCoordinatesList = gpxManager.getGeoCoordinatesList(track: gpxTrack)
        let diaryGeoPolyline = try! GeoPolyline(vertices: diaryGeoCoordinatesList)
        let distanceTravelled = getLengthOfGeoPolylineInMeters(diaryGeoPolyline)

        addMapPolyline(diaryGeoPolyline)
        animateCameraTo(diaryGeoCoordinatesList)

        updateMessage("Diary Entry from: " + gpxTrack.description + "\n" +
                   "Hike Distance: \(distanceTravelled) m")
    }

    private func deleteDiaryEntry(index: Int) {
        let isSuccess = gpxManager.deleteGPXTrack(index: index)
        print("Deleted entry: \(isSuccess)")
    }

    private func getMenuEntryKeys() -> [String] {
        var entryKeys: [String] = []
        for track in gpxManager.gpxDocument.tracks {
            entryKeys.append(track.name)
        }
        return entryKeys
    }

    private func getMenuEntryDescriptions() -> [String] {
        var entryDescriptions: [String] = []
        for track in gpxManager.gpxDocument.tracks {
            entryDescriptions.append("Hike done on: " + track.description)
        }
        return entryDescriptions
    }

    private func animateCameraToCurrentLocation() {
        if let currentLocation = herePositioningProvider.getLastKnownLocation() {
            let geoCoordinatesUpdate = GeoCoordinatesUpdate(currentLocation.coordinates)
            let durationInSeconds = TimeInterval(3)
            let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 500)
            let animation = MapCameraAnimationFactory.flyTo(target: geoCoordinatesUpdate,
                                                            zoom: distanceInMeters,
                                                            bowFactor: 1,
                                                            duration: durationInSeconds)
            mapView.camera.startAnimation(animation)
        }
    }

    private func animateCameraTo(_ geoCoordinateList: [GeoCoordinates]) {
        // We want to show the polyline fitting in the map view with an additional padding of 50 pixels.
        let origin:Point2D = Point2D(x: 50.0, y: 50.0)
        let sizeInPixels:Size2D = Size2D(width: mapView.viewportSize.width - 100, height: mapView.viewportSize.height - 100)
        let mapViewport = Rectangle2D(origin: origin, size: sizeInPixels)

        // Untilt and unrotate the map.
        let bearing: Double = 0
        let tilt: Double = 0
        let geoOrientationUpdate = GeoOrientationUpdate(bearing: bearing, tilt: tilt)

        // For very short polylines we want to have at least a distance of 100 meters.
        let minDistanceInMeters = MapMeasure(kind: .distanceInMeters, value: 100)

        let mapCameraUpdate = MapCameraUpdateFactory.lookAt(geoCoordinateList,
                                                            viewRectangle: mapViewport,
                                                            orientation: geoOrientationUpdate,
                                                            measureLimit: minDistanceInMeters)

        // Create animation.
        let durationInSeconds = TimeInterval(3)
        let mapCameraAnimation = MapCameraAnimationFactory.createAnimation(from: mapCameraUpdate,
                                                                           duration: durationInSeconds,
                                                                           easing: Easing(EasingFunction.inCubic))
        mapView.camera.startAnimation(mapCameraAnimation)
    }

    private func updateMessage(_ message: String) {
        textViewUpdateDelegate?.updateTextViewMessage(message)
    }
    
    // Method to convert and fetch saved hiking data into list of HikingDiaryEntry objects.
    func getPastHikingDiaryEntries() -> [HikingDiaryEntry] {
        var hikingDiaryEntries: [HikingDiaryEntry] = []
        hikingDiaryEntries = zip(getMenuEntryKeys(), getMenuEntryDescriptions()).map { (title, description) in
            return HikingDiaryEntry(title: title, description: description)
        }
        return hikingDiaryEntries
    }
    
    func deletetHikeEntry(at index: Int) {
        pastHikingDiaryEntries.remove(at: index)
        deleteDiaryEntry(index: index)
    }
    
    func loadHikeEntry(index: Int) {
        loadDiaryEntry(index: index)
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

extension HikingDiaryExample: TextViewUpdateDelegate {
    func updateTextViewMessage(_ message: String) {
        textViewUpdateDelegate?.updateTextViewMessage(message)
    }
}

