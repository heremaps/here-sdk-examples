/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

class MapItemsExample: TapDelegate {

    private let viewController: UIViewController
    private let mapView: MapView
    private var mapMarkers = [MapMarker]()
    private var mapMarkers3D = [MapMarker3D]()
    private var mapMarkerClusters = [MapMarkerCluster]()
    private var locationIndicators = [LocationIndicator]()
    private let mapCenterGeoCoordinates = GeoCoordinates(latitude: 52.51760485151816, longitude: 13.380312380535472)

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        mapView.camera.lookAt(point: mapCenterGeoCoordinates,
                      distanceInMeters: 1000 * 10)

        // Setting a tap delegate to pick markers from map.
        mapView.gestures.tapDelegate = self

        showDialog(title: "Note", message: "You can tap 2D markers.")
    }

    func onAnchoredButtonClicked() {
        unTiltMap()

        for _ in 1...10 {
            let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

            // Centered on location. Shown below the POI image to indicate the location.
            addCircleMapMarker(geoCoordinates: geoCoordinates)

            // Anchored, pointing to location.
            addPOIMapMarker(geoCoordinates: geoCoordinates)
        }
    }

    func onCenteredButtonClicked() {
        unTiltMap()

        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Centered on location.
        addPhotoMapMarker(geoCoordinates: geoCoordinates)

        // Centered on location. Shown above the photo marker to indicate the location.
        // The draw order is determined from what is first added to the map.
        addCircleMapMarker(geoCoordinates: geoCoordinates)
    }

    func onMapMarkerClusterButtonClicked() {
        guard
            let image = UIImage(named: "blue_square.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        let clusterMapImage = MapImage(pixelData: imageData,
                                       imageFormat: ImageFormat.png)

        let mapMarkerCluster = MapMarkerCluster(imageStyle: MapMarkerCluster.ImageStyle(image: clusterMapImage))
        mapView.mapScene.addMapMarkerCluster(mapMarkerCluster)
        mapMarkerClusters.append(mapMarkerCluster)

        for _ in 1...10 {
            mapMarkerCluster.addMapMarker(marker: createRandomMapMarkerInViewport())
        }
    }

    func createRandomMapMarkerInViewport() -> MapMarker {
        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        guard
            let image = UIImage(named: "green_square.png"),
            let imageData = image.pngData() else {
                fatalError("Error: Image not found.")
        }

        let mapImage = MapImage(pixelData: imageData,
                                       imageFormat: ImageFormat.png)
        let mapMarker = MapMarker(at: geoCoordinates, image: mapImage)
        return mapMarker
    }

    func onLocationIndicatorPedestrianButtonClicked() {
        unTiltMap()

        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Centered on location.
        addLocationIndicator(geoCoordinates: geoCoordinates,
                             style: LocationIndicator.IndicatorStyle.pedestrian)
    }

    func onLocationIndicatorNavigationButtonClicked() {
        unTiltMap()

        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Centered on location.
        addLocationIndicator(geoCoordinates: geoCoordinates,
                             style: LocationIndicator.IndicatorStyle.navigation)
    }

    public func onFlatMapMarkerButtonClicked() {
        // Tilt the map for a better 3D effect.
        tiltMap()

        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Adds a flat POI marker that rotates and tilts together with the map.
        addFlatMarker3D(geoCoordinates: geoCoordinates)

        // A centered 2D map marker to indicate the exact location.
        // Note that 3D map markers are always drawn on top of 2D map markers.
        addCircleMapMarker(geoCoordinates: geoCoordinates)
    }

    public func onMapMarker3DClicked() {
        // Tilt the map for a better 3D effect.
        tiltMap()

        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Adds a textured 3D model.
        // It's origin is centered on the location.
        addMapMarker3D(geoCoordinates: geoCoordinates)
    }

    func onClearButtonClicked() {
        clearMap()
    }

    private func addPOIMapMarker(geoCoordinates: GeoCoordinates) {
        // Drag & Drop the image to Assets.xcassets (or simply add the image as file to the project).
        // You can add multiple resolutions to Assets.xcassets that will be used depending on the
        // display size.
        guard
            let image = UIImage(named: "poi.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        let anchorPoint = Anchor2D(horizontal: 0.5, vertical: 1)
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png),
                                  anchor: anchorPoint)

        let metadata = Metadata()
        metadata.setString(key: "key_poi", value: "This is a POI.")
        mapMarker.metadata = metadata

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func addPhotoMapMarker(geoCoordinates: GeoCoordinates) {
        guard
            let image = UIImage(named: "here_car.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        let mapImage = MapImage(pixelData: imageData,
                                imageFormat: ImageFormat.png)
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: mapImage)

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func addCircleMapMarker(geoCoordinates: GeoCoordinates) {
        guard
            let image = UIImage(named: "circle.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png))
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func addLocationIndicator(geoCoordinates: GeoCoordinates,
                                      style: LocationIndicator.IndicatorStyle) {
        let locationIndicator = LocationIndicator()
        locationIndicator.locationIndicatorStyle = style

        // A LocationIndicator is intended to mark the user's current location,
        // including a bearing direction.
        var location = Location(coordinates: geoCoordinates, timestamp: Date())
        location.bearingInDegrees = getRandom(min: 0, max: 360)

        locationIndicator.updateLocation(location)

        // A LocationIndicator listens to the lifecycle of the map view,
        // therefore, for example, it will get destroyed when the map view gets destroyed.
        mapView.addLifecycleDelegate(locationIndicator)
        locationIndicators.append(locationIndicator)
    }

    // A location indicator can be switched to a gray state, for example, to indicate a weak GPS signal.
    public func toggleActiveStateForLocationIndicator() {
        for locationIndicator in locationIndicators {
            let isActive = locationIndicator.isActive
            // Toggle between active / inactive state.
            locationIndicator.isActive = !isActive
        }
    }

    private func addFlatMarker3D(geoCoordinates: GeoCoordinates) {
        // Place the files to an "assets" directory via drag & drop.
        // Adjust file name and path as appropriate for your project.
        // Note: The bottom of the plane is centered on the origin.
        let geometryFile = getResourceStringFromBundle(name: "plane", type: "obj")

        // The POI texture is a square, so we can easily wrap it onto the 2 x 2 plane model.
        let textureFile = getResourceStringFromBundle(name: "poi_texture", type: "png")

        let mapMarker3DModel = MapMarker3DModel(geometryFilePath: geometryFile, textureFilePath: textureFile)
        let mapMarker3D = MapMarker3D(at: geoCoordinates, model: mapMarker3DModel)
        // Scale marker. Note that we used a normalized length of 2 units in 3D space.
        mapMarker3D.scale = 70

        mapView.mapScene.addMapMarker3d(mapMarker3D)
        mapMarkers3D.append(mapMarker3D)
    }

    private func addMapMarker3D(geoCoordinates: GeoCoordinates) {
        // Place the files to an "assets" directory via drag & drop.
        // Adjust file name and path as appropriate for your project.
        let geometryFile = getResourceStringFromBundle(name: "obstacle", type: "obj")
        let textureFile = getResourceStringFromBundle(name: "obstacle_texture", type: "png")

        let mapMarker3DModel = MapMarker3DModel(geometryFilePath: geometryFile, textureFilePath: textureFile)
        let mapMarker3D = MapMarker3D(at: geoCoordinates, model: mapMarker3DModel)
        mapMarker3D.scale = 6

        mapView.mapScene.addMapMarker3d(mapMarker3D)
        mapMarkers3D.append(mapMarker3D)
    }

    private func getResourceStringFromBundle(name: String, type: String) -> String {
        let bundle = Bundle(for: ViewController.self)
        let resourceUrl = bundle.url(forResource: name,
                                     withExtension: type)
        guard let resourceString = resourceUrl?.path else {
            fatalError("Error: Resource not found!")
        }

        return resourceString
    }

    private func clearMap() {
        mapView.mapScene.removeMapMarkers(mapMarkers)
        mapMarkers.removeAll()

        for mapMarker3D in mapMarkers3D {
            mapView.mapScene.removeMapMarker3d(mapMarker3D)
        }
        mapMarkers3D.removeAll()

        for locationIndicator in locationIndicators {
            mapView.removeLifecycleDelegate(locationIndicator)
        }
        locationIndicators.removeAll()

        for mapMarkerCluster in mapMarkerClusters {
            mapView.mapScene.removeMapMarkerCluster(mapMarkerCluster)
        }
        mapMarkerClusters.removeAll()
    }

    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        mapView.pickMapItems(at: origin, radius: 2, completion: onMapItemsPicked)
    }

    // Completion handler to receive picked map items.
    func onMapItemsPicked(pickedMapItems: PickMapItemsResult?) {
        // Note that MapMarker items contained in a cluster are not part of pickedMapItems?.markers.
        if let groupingList = pickedMapItems?.clusteredMarkers {
            handlePickedMapMarkerClusters(groupingList)
        }
        
        // Note that 3D map markers can't be picked yet. Only marker, polgon and polyline map items are pickable.
        guard let topmostMapMarker = pickedMapItems?.markers.first else {
            return
        }
        
        if let message = topmostMapMarker.metadata?.getString(key: "key_poi") {
            showDialog(title: "Map Marker picked", message: message)
            return
        }

        showDialog(title: "Map marker picked:", message: "Location: \(topmostMapMarker.coordinates)")
    }

    private func handlePickedMapMarkerClusters(_ groupingList: [MapMarkerCluster.Grouping]) {
        guard let topmostGrouping = groupingList.first else {
            return
        }
        
        let clusterSize = topmostGrouping.markers.count
        if (clusterSize == 0) {
            // This cluster does not contain any MapMarker items.
            return
        }
        if (clusterSize == 1) {
            showDialog(title: "Map Marker picked", message: "This MapMarker belongs to a cluster.")
        } else {
            showDialog(title: "Map marker cluster picked",
                       message: "Number of contained markers in this cluster: \(clusterSize). Total number of markers in this MapMarkerCluster: \(topmostGrouping.parent.markers.count)")
        }
    }
    
    private func createRandomGeoCoordinatesAroundMapCenter() -> GeoCoordinates {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)
        let centerPoint2D = Point2D(x: mapViewWidthInPixels / 2,
                                    y: mapViewHeightInPixels / 2)

        let centerGeoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: centerPoint2D)
        let lat = centerGeoCoordinates!.latitude
        let lon = centerGeoCoordinates!.longitude
        return GeoCoordinates(latitude: getRandom(min: lat - 0.02,
                                                  max: lat + 0.02),
                              longitude: getRandom(min: lon - 0.02,
                                                   max: lon + 0.02))
    }

    private func getRandom(min: Double, max: Double) -> Double {
        return Double.random(in: min ... max)
    }

    private func tiltMap() {
        let bearing = mapView.camera.state.orientationAtTarget.bearing
        let tilt: Double = 60
        let targetOrientation = GeoOrientationUpdate(bearing: bearing,
                                                     tilt: tilt)
        mapView.camera.setOrientationAtTarget(targetOrientation)
    }

    private func unTiltMap() {
        let bearing = mapView.camera.state.orientationAtTarget.bearing
        let tilt: Double = 0
        let targetOrientation = GeoOrientationUpdate(bearing: bearing,
                                                     tilt: tilt)
        mapView.camera.setOrientationAtTarget(targetOrientation)
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }
}
