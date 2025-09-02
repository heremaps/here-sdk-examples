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

class MapItemsExample: TapDelegate {
    
    private let mapView: MapView
    private var mapMarkers = [MapMarker]()
    private var mapMarkers3D = [MapMarker3D]()
    private var mapMarkerClusters = [MapMarkerCluster]()
    private var locationIndicators = [LocationIndicator]()
    private let mapCenterGeoCoordinates = GeoCoordinates(latitude: 52.51760485151816, longitude: 13.380312380535472)

    init(mapView: MapView) {
        self.mapView = mapView
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        mapView.camera.lookAt(point: mapCenterGeoCoordinates,
                              zoom: distanceInMeters)

        // Setting a tap delegate to pick markers from map.
        mapView.gestures.tapDelegate = self

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        showDialog(title: "Note", message: "You can tap 2D markers.")
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        
        // Textured landmarks are only available with the Navigate License:
        // mapView.mapScene.enableFeatures([MapFeatures.landmarks : MapFeatureModes.landmarksTextured])
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

    func onMarkerWithTextButtonClicked() {
        // Drag & Drop the image to Assets.xcassets (or simply add the image as file to the project).
        // You can add multiple resolutions to Assets.xcassets that will be used depending on the
        // display size.
        guard
            let image = UIImage(named: "poi.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        
        // The bottom, middle position should point to the location.
        // By default, the anchor point is set to 0.5, 0.5.
        let anchorPoint = Anchor2D(horizontal: 0.5, vertical: 1)
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png),
                                  anchor: anchorPoint)

        let textStyleCurrent = mapMarker.textStyle
        var textStyleNew = MapMarker.TextStyle()
        let textSizeInPixels: Double = 30
        let textOutlineSizeInPixels: Double = 5

        // Placement priority is based on order. It is only effective when
        // overlap is disallowed. The below setting will show the text
        // at the bottom of the marker, but when the marker or the text overlaps
        // then the text will swap to the top before the marker disappears completely.
        // Note: By default, markers do not disappear when they overlap.
        let placements: [MapMarker.TextStyle.Placement] = [.bottom, .top]
        mapMarker.isOverlapAllowed = false
        
        do {
            textStyleNew = try MapMarker.TextStyle(
                textSize: textSizeInPixels,
                textColor: textStyleCurrent.textColor,
                textOutlineSize: textOutlineSizeInPixels,
                textOutlineColor: textStyleCurrent.textOutlineColor,
                placements: placements
            )
        } catch let error as MapMarker.TextStyle.InstantiationError {
            // An error code will indicate what went wrong, for example, when negative values are set for text size.
            print("TextStyle: Error code: \(error.rawValue)")
        } catch {
            // Handle any other errors that might be thrown
            print("An unexpected error occurred: \(error)")
        }

        mapMarker.text = "Hello Text"
        mapMarker.textStyle = textStyleNew
        
        let metadata = Metadata()
        metadata.setString(key: "key_poi_text", value: "This is a POI with text.")
        mapMarker.metadata = metadata

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }
    
    func onMapMarkerClusterButtonClicked() {
        guard
            let image = UIImage(named: "green_square.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        let clusterMapImage = MapImage(pixelData: imageData,
                                       imageFormat: ImageFormat.png)

        // Defines a text that indicates how many markers are included in the cluster.
        var counterStyle = MapMarkerCluster.CounterStyle()
        counterStyle.textColor = UIColor.black
        counterStyle.fontSize = 40
        counterStyle.maxCountNumber = 9
        counterStyle.aboveMaxText = "+9"

        let mapMarkerCluster = MapMarkerCluster(imageStyle: MapMarkerCluster.ImageStyle(image: clusterMapImage),
                                                counterStyle: counterStyle)
        mapView.mapScene.addMapMarkerCluster(mapMarkerCluster)
        mapMarkerClusters.append(mapMarkerCluster)

        var index = 1
        for _ in 1...10 {
            let indexString = String(index)
            mapMarkerCluster.addMapMarker(marker: createRandomMapMarkerInViewport(indexString))
            index = index + 1
        }
    }

    func createRandomMapMarkerInViewport(_ metaDataText: String) -> MapMarker {
        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()
        guard
            let image = UIImage(named: "green_square.png"),
            let imageData = image.pngData() else {
                fatalError("Error: Image not found.")
        }

        let mapImage = MapImage(pixelData: imageData,
                                imageFormat: ImageFormat.png)
        let mapMarker = MapMarker(at: geoCoordinates, image: mapImage)

        let metadata = Metadata()
        metadata.setString(key: "key_cluster", value: metaDataText)
        mapMarker.metadata = metadata

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

        // It's origin is centered on the location.
        addFlatMarker(geoCoordinates: geoCoordinates)

        // A centered 2D map marker to indicate the exact location.
        // Note that 3D map markers are always drawn on top of 2D map markers.
        addCircleMapMarker(geoCoordinates: geoCoordinates)
    }

    public func on2DTextureButtonClicked() {
        // Tilt the map for a better 3D effect.
        tiltMap()

        let geoCoordinates = createRandomGeoCoordinatesAroundMapCenter()

        // Adds a flat POI marker that rotates and tilts together with the map.
        add2DTexture(geoCoordinates: geoCoordinates)

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

        // Optionally, enable a fade in-out animation.
        let durationInSeconds: TimeInterval = 3
        mapMarker.fadeDuration = durationInSeconds

        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func addLocationIndicator(geoCoordinates: GeoCoordinates,
                                      style: LocationIndicator.IndicatorStyle) {
        let locationIndicator = LocationIndicator()
        locationIndicator.locationIndicatorStyle = style
        
        // A LocationIndicator is intended to mark the user's current location,
        // including a bearing direction.
        var location = Location(coordinates: geoCoordinates)
        location.time = Date()
        location.bearingInDegrees = getRandom(min: 0, max: 360)

        locationIndicator.updateLocation(location)

        locationIndicator.enable(for: mapView)
        
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

    private func add2DTexture(geoCoordinates: GeoCoordinates) {
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

    private func addFlatMarker(geoCoordinates: GeoCoordinates) {
        guard
            let image = UIImage(named: "poi.png"),
            let imageData = image.pngData() else {
                print("Error: Image not found.")
                return
        }

        // The default scale factor of the map marker is 1.0. For a scale of 2, the map marker becomes 2x larger.
        // For a scale of 0.5, the map marker shrinks to half of its original size.
        let scaleFactor: Double = 0.5

        let mapImage:MapImage = MapImage(pixelData: imageData, imageFormat: ImageFormat.png)

        // With DENSITY_INDEPENDENT_PIXELS the map marker will have a constant size on the screen regardless if the map is zoomed in or out.
        let mapMarker3D: MapMarker3D = MapMarker3D(at: geoCoordinates, image: mapImage, scale: scaleFactor, unit: RenderSize.Unit.densityIndependentPixels)

        mapView.mapScene.addMapMarker3d(mapMarker3D)
        mapMarkers3D.append(mapMarker3D)
    }

    private func addMapMarker3D(geoCoordinates: GeoCoordinates) {
        // Place the files to an "assets" directory via drag & drop.
        // Adjust file name and path as appropriate for your project.
        let geometryFile = getResourceStringFromBundle(name: "obstacle", type: "obj")
        let textureFile = getResourceStringFromBundle(name: "obstacle_texture", type: "png")

        // Without depth check, 3D models are rendered on top of everything. With depth check enabled,
        // it may be hidden by buildings. In addition:
        // If a 3D object has its center at the origin of its internal coordinate system,
        // then parts of it may be rendered below the ground surface (altitude < 0).
        // Note that the HERE SDK map surface is flat, following a Mercator or Globe projection.
        // Therefore, a 3D object becomes visible when the altitude of its location is 0 or higher.
        // By default, without setting a scale factor, 1 unit in 3D coordinate space equals 1 meter.
        let geoCoordinatesWithAltitude = GeoCoordinates(latitude: geoCoordinates.latitude,
                                                        longitude: geoCoordinates.longitude,
                                                        altitude: 18.0)
        let mapMarker3DModel = MapMarker3DModel(geometryFilePath: geometryFile, textureFilePath: textureFile)
        let mapMarker3D = MapMarker3D(at: geoCoordinatesWithAltitude, model: mapMarker3DModel)
        mapMarker3D.scale = 6
        mapMarker3D.isDepthCheckEnabled = true

        mapView.mapScene.addMapMarker3d(mapMarker3D)
        mapMarkers3D.append(mapMarker3D)
    }

    private func getResourceStringFromBundle(name: String, type: String) -> String {
        // Access the main bundle directly in SwiftUI
        let bundle = Bundle.main
        guard let resourceUrl = bundle.url(forResource: name, withExtension: type) else {
            fatalError("Error: Resource not found!")
        }
        
        return resourceUrl.path
    }
    
    private func clearMap() {
        mapView.mapScene.removeMapMarkers(mapMarkers)
        mapMarkers.removeAll()
        
        for mapMarker3D in mapMarkers3D {
            mapView.mapScene.removeMapMarker3d(mapMarker3D)
        }
        mapMarkers3D.removeAll()
        
        for locationIndicator in locationIndicators {
            // Remove indicator from map view.
            locationIndicator.disable()
        }
        locationIndicators.removeAll()
        
        for mapMarkerCluster in mapMarkerClusters {
            mapView.mapScene.removeMapMarkerCluster(mapMarkerCluster)
        }
        mapMarkerClusters.removeAll()
    }
    
    // Conform to the TapDelegate protocol.
    func onTap(origin: Point2D) {
        let originInPixels = Point2D(x:origin.x,y:origin.y);
        let sizeInPixels = Size2D(width:1,height:1);
        let rectangle = Rectangle2D(origin: originInPixels, size: sizeInPixels);
        
        // Creates a list of map content type from which the results will be picked.
        // The content type values can be mapContent, mapItems and customLayerData.
        var contentTypesToPickFrom = Array<MapScene.MapPickFilter.ContentType>();
        
        // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need map markers so adding the mapItems filter.
        contentTypesToPickFrom.append(MapScene.MapPickFilter.ContentType.mapItems);
        let filter = MapScene.MapPickFilter(filter: contentTypesToPickFrom);
        
        mapView.pick(filter: filter, inside: rectangle, completion:onMapItemsPicked);
    }
    
    // Completion handler to receive picked map items.
    func onMapItemsPicked(mapPickResults: MapPickResult?) {
        let pickedMapItems = mapPickResults?.mapItems;
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
        
        if let message = topmostMapMarker.metadata?.getString(key: "key_poi_text") {
            showDialog(title: "Map Marker with text picked", message: message)
            // You can update text for a marker on-the-fly.
            topmostMapMarker.text = "Marker was picked."
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
            let metadata = getClusterMetadata(topmostGrouping.markers.first!)
            showDialog(title: "Map Marker picked", message: "This MapMarker belongs to a cluster. Metadata: \(metadata)")
        } else {
            var metadata = ""
            for mapMarker in topmostGrouping.markers {
                metadata += getClusterMetadata(mapMarker)
                metadata += " "
            }
            let metadataMessage = "Contained Metadata: " + metadata + ". "
            showDialog(title: "Map marker cluster picked",
                       message: "Number of contained markers in this cluster: \(clusterSize). \(metadataMessage) Total number of markers in this MapMarkerCluster: \(topmostGrouping.parent.markers.count)")
        }
    }
    
    private func getClusterMetadata(_ mapMarker: MapMarker) -> String {
        if let message = mapMarker.metadata?.getString(key: "key_cluster") {
            return message
        }
        return "No metadata."
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
