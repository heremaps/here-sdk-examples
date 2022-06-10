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

class ViewController: UIViewController, AnimationDelegate, LocationDelegate {

    @IBOutlet var mapView: MapView!

    private let routeStartGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
    private let distanceInMeters: Double = 1000

    private var routingEngine: RoutingEngine?
    private var visualNavigator: VisualNavigator?
    private var locationSimulator: LocationSimulator?
    private var defaultLocationIndicator: LocationIndicator?
    private var customLocationIndicator: LocationIndicator?
    private var lastKnownLocation: Location?
    private var isVisualNavigatorRenderingStarted = false
    private var isDefaultLocationIndicator = true
    private var myRoute: Route?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Configure the map.
        let camera = mapView.camera
        let distanceToEarthInMeters: Double = 1000
        camera.lookAt(point: routeStartGeoCoordinates,
                      zoom: MapMeasure(kind: .distance, value: distanceToEarthInMeters))

        startAppLogic()
    }

    private func startAppLogic() {
        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }

        do {
            // Without a route set, this starts tracking mode.
            try visualNavigator = VisualNavigator()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize VisualNavigator. Cause: \(engineInstantiationError)")
        }

        // Enable a few map layers that might be useful to see for drivers.
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.trafficFlow, visibility: VisibilityState.visible)
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.trafficIncidents, visibility: VisibilityState.visible)
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.safetyCameras, visibility: VisibilityState.visible)
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.vehicleRestrictions, visibility: VisibilityState.visible)

        defaultLocationIndicator = LocationIndicator()
        customLocationIndicator = createCustomLocationIndicator()

        // Show indicator on map. We start with the built-in default LocationIndicator.
        isDefaultLocationIndicator = true
        switchToPedestrianLocationIndicator()

        showDialog(title: "Custom Navigation",
                   message: "Start / stop simulated route guidance. Toggle between custom / default LocationIndicator.")
    }

    private func createCustomLocationIndicator() -> LocationIndicator {
        // Create an "assets" directory and add the folder with content via drag & drop.
        // Adjust file name and path as appropriate for your project.
        let pedGeometryFile = getResourceStringFromBundle(name: "custom_location_indicator_pedestrian", type: "obj")
        let pedTextureFile = getResourceStringFromBundle(name: "custom_location_indicator_pedestrian", type: "png")
        let pedestrianMapMarker3DModel = MapMarker3DModel(geometryFilePath: pedGeometryFile,
                                                          textureFilePath: pedTextureFile)

        let navGeometryFile = getResourceStringFromBundle(name: "custom_location_indicator_navigation", type: "obj")
        let navTextureFile = getResourceStringFromBundle(name: "custom_location_indicator_navigation", type: "png")
        let navigationMapMarker3DModel = MapMarker3DModel(geometryFilePath: navGeometryFile,
                                                          textureFilePath: navTextureFile)

        let locationIndicator = LocationIndicator()
        let scaleFactor: Double = 3

        // Note: For this example app, we use only simulated location data.
        // Therefore, we do not create a custom LocationIndicator for
        // MarkerType.PEDESTRIAN_INACTIVE and MarkerType.NAVIGATION_INACTIVE.
        // If set with a gray texture model, the type can be switched by calling locationIndicator.setActive(false)
        // when the GPS accuracy is weak or no location was found.
        locationIndicator.setMarker3dModel(pedestrianMapMarker3DModel,
                                           scale: scaleFactor,
                                           type: LocationIndicator.MarkerType.pedestrian)
        locationIndicator.setMarker3dModel(navigationMapMarker3DModel,
                                           scale: scaleFactor,
                                           type: LocationIndicator.MarkerType.navigation)
        return locationIndicator
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

    // Calculate a fixed route for testing and start guidance simulation along the route.
    @IBAction func startButtonClicked(_ sender: Any) {
        let startWaypoint = Waypoint(coordinates: routeStartGeoCoordinates)
        let destinationWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.530905, longitude: 13.385007))

        routingEngine!.calculateRoute(with: [startWaypoint, destinationWaypoint],
                                     carOptions: CarOptions()) { (routingError, routes) in
            if let error = routingError {
                print("Error while calculating a route: \(error)")
                return
            }

            // When routingError is nil, routes is guaranteed to contain at least one route.
            self.myRoute = routes!.first!
            self.animateToRouteStart()
        }
    }

    // Stop guidance simulation and switch pedestrian LocationIndicator on.
    @IBAction func stopButtonClicked(_ sender: Any) {
        stopGuidance()
    }

    // Toogle between the default LocationIndicator and custom LocationIndicator.
    // The default LocationIndicator uses a 3D asset that is part of the HERE SDK.
    // The custom LocationIndicator uses different 3D assets, see asset folder.
    @IBAction func toggleButtonClicked(_ sender: Any) {
        // Toggle state.
        isDefaultLocationIndicator = !isDefaultLocationIndicator

        // Select pedestrian or navigation assets.
        if isVisualNavigatorRenderingStarted {
            switchToNavigationLocationIndicator()
        } else {
            switchToPedestrianLocationIndicator()
        }
    }

    private func switchToPedestrianLocationIndicator() {
        if isDefaultLocationIndicator {
            defaultLocationIndicator?.enable(for: mapView)
            defaultLocationIndicator?.locationIndicatorStyle = LocationIndicator.IndicatorStyle.pedestrian
            customLocationIndicator?.disable()
        } else {
            defaultLocationIndicator?.disable();
            customLocationIndicator?.enable(for: mapView);
            customLocationIndicator?.locationIndicatorStyle = LocationIndicator.IndicatorStyle.pedestrian
        }

        // Set last location from LocationSimulator.
        defaultLocationIndicator?.updateLocation(getLastKnownLocationLocation())
        customLocationIndicator?.updateLocation(getLastKnownLocationLocation())
    }

    private func switchToNavigationLocationIndicator() {
        if isDefaultLocationIndicator {
            // By default, the VisualNavigator adds a LocationIndicator on its own.
            defaultLocationIndicator?.disable()
            customLocationIndicator?.disable()
            visualNavigator?.customLocationIndicator = nil
        } else {
            defaultLocationIndicator?.disable()
            customLocationIndicator?.enable(for: mapView)
            customLocationIndicator?.locationIndicatorStyle = LocationIndicator.IndicatorStyle.navigation
            visualNavigator?.customLocationIndicator = customLocationIndicator

            // Note that the type of the LocationIndicator is taken from the route's TransportMode.
            // It cannot be overriden during guidance.
            // During tracking mode (not shown in this app) you can specify the marker type via:
            // visualNavigator?.trackingTransportMode = .pedestrian
        }

        // Location is set by VisualNavigator for smooth interpolation.
    }

    private func getLastKnownLocationLocation() -> Location {
        if lastKnownLocation == nil {
            // A LocationIndicator is intended to mark the user's current location,
            // including a bearing direction.
            // For testing purposes, we create below a Location object. Usually, you want to get this from
            // a GPS sensor instead. Check the Positioning example app for this.
            var location = Location(coordinates: routeStartGeoCoordinates)
            location.time = Date()
            return location
        }

        // This location is taken from the LocationSimulator that provides locations along the route.
        return lastKnownLocation!
    }

    // Animate to custom guidance perspective, centered on start location of route.
    private func animateToRouteStart() {
        // The first coordinate marks the start location of the route.
        let routeStart = myRoute!.geometry.vertices.first!
        let geoCoordinatesUpdate = GeoCoordinatesUpdate(routeStart)
        
        let bearingInDegrees: Double? = nil
        let tiltInDegrees: Double = 70
        let orientationUpdate = GeoOrientationUpdate(bearing: bearingInDegrees, tilt: tiltInDegrees)
        
        let distanceInMeters: Double = 50
        let mapMeasure = MapMeasure(kind: .distance, value: distanceInMeters)

        let durationInSeconds: TimeInterval = 3
        let animation = MapCameraAnimationFactory.flyTo(target: geoCoordinatesUpdate,
                                                        orientation: orientationUpdate,
                                                        zoom: mapMeasure,
                                                        bowFactor: 1,
                                                        duration: durationInSeconds)
        mapView.camera.startAnimation(animation, animationDelegate: self)
    }

    // Conforming to AnimationDelegate.
    func onAnimationStateChanged(state: AnimationState) {
        if (state == AnimationState.completed
            || state == AnimationState.cancelled) {
            startGuidance(route: myRoute!);
        }
    }

    private func animateToDefaultMapPerspective() {
        let target = mapView.camera.state.targetCoordinates
        let geoCoordinatesUpdate = GeoCoordinatesUpdate(target)
        
        // By setting nil we keep the current bearing rotation of the map.
        let bearingInDegrees: Double? = nil
        let tiltInDegrees: Double = 0
        let orientationUpdate = GeoOrientationUpdate(bearing: bearingInDegrees, tilt: tiltInDegrees)
        
        let mapMeasure = MapMeasure(kind: .distance, value: distanceInMeters)

        let durationInSeconds: TimeInterval = 3
        let animation = MapCameraAnimationFactory.flyTo(target: geoCoordinatesUpdate,
                                                        orientation: orientationUpdate,
                                                        zoom: mapMeasure,
                                                        bowFactor: 1,
                                                        duration: durationInSeconds)
        mapView.camera.startAnimation(animation)        
    }

    private func startGuidance(route: Route) {
        if isVisualNavigatorRenderingStarted {
            return
        }

        // Set custom guidance perspective.
        customizeGuidanceView()

        // This enables a navigation view and adds a LocationIndicator.
        visualNavigator?.startRendering(mapView: mapView)
        isVisualNavigatorRenderingStarted = true

        // Note: By default, when VisualNavigator starts rendering, a default LocationIndicator is added
        // by the HERE SDK automatically.
        switchToNavigationLocationIndicator()

        // Set a route to follow. This leaves tracking mode.
        visualNavigator?.route = route

        // This app does not use real location updates. Instead it provides location updates based
        // on the geographic coordinates of a route using HERE SDK's LocationSimulator.
        startRouteSimulation(route: route)
    }

    private func stopGuidance() {
        visualNavigator?.stopRendering()
        isVisualNavigatorRenderingStarted = false

        locationSimulator?.stop()

        // Note: By default, when VisualNavigator stops rendering, no LocationIndicator is visible.
        switchToPedestrianLocationIndicator()
        
        animateToDefaultMapPerspective()
    }

    private func customizeGuidanceView() {
        // Set custom zoom level and tilt.
        let cameraDistanceInMeters: Double = 50 // Defaults to 150.
        let cameraTiltInDegrees: Double = 70 // Defaults to 50.
        // Disable North-Up mode by setting null. Enable North-up mode by setting 0.
        // By default, North-Up mode is disabled.
        let cameraBearingInDegrees: Double? = nil

        // The CameraSettings can be updated during guidance at any time as often as desired.
        visualNavigator?.cameraSettings = CameraSettings(cameraDistanceInMeters: cameraDistanceInMeters,
                                                         cameraTiltInDegrees: cameraTiltInDegrees,
                                                         cameraBearingInDegrees: cameraBearingInDegrees)
    }

    private func startRouteSimulation(route: Route) {
        // Make sure to stop an existing LocationSimulator before starting a new one.
        locationSimulator?.stop();

        do {
            // Provides fake GPS signals based on the route geometry.
            try locationSimulator = LocationSimulator(route: route,
                                                      options: LocationSimulatorOptions())
        } catch let instantiationError {
            fatalError("Failed to initialize LocationSimulator. Cause: \(instantiationError)")
        }

        locationSimulator?.delegate = self
        locationSimulator?.start()
    }

    // Conforming to LocationDelegate.
    func onLocationUpdated(_ location: Location) {
        // Feed location data into the VisualNavigator.
        visualNavigator?.onLocationUpdated(location)
        lastKnownLocation = location
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
