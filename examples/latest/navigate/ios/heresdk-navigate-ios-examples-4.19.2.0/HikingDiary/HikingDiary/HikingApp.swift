/*
 * Copyright (C) 2022-2024 HERE Europe B.V.
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

// An app that tracks the user's location and allows to record the travelled path with a GPXTrackWriter.
class HikingApp: LocationDelegate {

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
    private let messageTextView = UITextView()
    private var locationFilter: LocationFilterStrategy

    init(mapView: MapView) {
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

        animateCameraToCurrentLocation()

        setupMessageView()
        setMessage("** Hiking Diary **")
    }

    func onStartHikingButtonClicked() {
        clearMap()
        isHiking = true
        isGPXTrackLoaded = false
        animateCameraToCurrentLocation()
        setMessage("Start Hike.")

        // Create a new GPXTrackWriter to record this trip.
        gpxTrackWriter = GPXTrackWriter()
    }

    func onStopHikingButtonClicked() {
        clearMap()

        if isHiking && isGPXTrackLoaded == false {
            saveDiaryEntry()
        } else {
            setMessage("Stopped.")
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
                setMessage("Hike Distance: \(distanceTravelled) m")
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
        setMessage("Saved Hike: \(result).")
    }

    // Load the selected diary entry and show the polyline related to that hike.
    public func loadDiaryEntry(index: Int) {
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

        setMessage("Diary Entry from: " + gpxTrack.description + "\n" +
                   "Hike Distance: \(distanceTravelled) m")
    }

    public func deleteDiaryEntry(index: Int) {
        let isSuccess = gpxManager.deleteGPXTrack(index: index)
        print("Deleted entry: \(isSuccess)")
    }

    public func getMenuEntryKeys() -> [String] {
        var entryKeys: [String] = []
        for track in gpxManager.gpxDocument.tracks {
            entryKeys.append(track.name)
        }
        return entryKeys
    }

    public func getMenuEntryDescriptions() -> [String] {
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
            let distanceInMeters = MapMeasure(kind: .distance, value: 500)
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
        let minDistanceInMeters = MapMeasure(kind: .distance, value: 100)

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

    // A permanent view to show scrollable text content.
    private func setupMessageView() {
        messageTextView.textColor = .white
        messageTextView.backgroundColor = UIColor(red: 0, green: 144 / 255, blue: 138 / 255, alpha: 1)
        messageTextView.layer.cornerRadius = 8
        messageTextView.isEditable = false
        messageTextView.textAlignment = NSTextAlignment.center
        messageTextView.font = .systemFont(ofSize: 14)
        messageTextView.frame = CGRect(x: 0, y: 0, width: mapView.frame.width * 0.6, height: mapView.frame.height * 0.085)
        messageTextView.center = CGPoint(x: mapView.frame.width * 0.5, y: mapView.frame.height * 0.9)

        UIView.transition(with: mapView, duration: 0.2, options: [.transitionCrossDissolve], animations: {
            self.mapView.addSubview(self.messageTextView)
        })
    }

    public func setMessage(_ message: String) {
        messageTextView.text = message
    }
}
