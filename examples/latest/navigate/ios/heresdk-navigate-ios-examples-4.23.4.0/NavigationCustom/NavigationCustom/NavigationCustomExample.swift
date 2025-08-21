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

// This example shows how to customize the navigation experience.
class NavigationCustomExample: AnimationDelegate, LocationDelegate {
    
    private let mapView: MapView
    
    private let routeStartGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)
    private let distanceInMeters: Double = 1000

    private var routingEngine: RoutingEngine
    private var visualNavigator: VisualNavigator
    private var locationSimulator: LocationSimulator?
    private var defaultLocationIndicator = LocationIndicator()
    private var customLocationIndicator = LocationIndicator()
    private var lastKnownLocation: Location?
    private var isDefaultLocationIndicator = true
    private var myRoute: Route?
    private var isCustomHaloColor = false
    private var defaultHaloColor: UIColor = .cyan
    private let defaultHaloAccurarcyInMeters = 30.0
    private let cameraTiltInDegrees = 40.0
    private let cameraDistanceInMeters = 200.0
    
    init(_ mapView: MapView) {
        self.mapView = mapView

        // Configure the map.
        let camera = mapView.camera
        let distanceToEarthInMeters: Double = 1000
        camera.lookAt(point: routeStartGeoCoordinates,
                      zoom: MapMeasure(kind: .distanceInMeters, value: distanceToEarthInMeters))
        
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

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        showDialog(title: "Custom Navigation",
                   message: "Start / stop simulated route guidance. Toggle between custom / default LocationIndicator.")
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Enable a few map layers that might be useful to see for drivers.
        mapView.mapScene.enableFeatures([MapFeatures.trafficFlow : MapFeatureModes.trafficFlowWithFreeFlow])
        mapView.mapScene.enableFeatures([MapFeatures.trafficIncidents : MapFeatureModes.defaultMode])
        mapView.mapScene.enableFeatures([MapFeatures.safetyCameras : MapFeatureModes.defaultMode])
        mapView.mapScene.enableFeatures([MapFeatures.vehicleRestrictions : MapFeatureModes.defaultMode])

        // Optionally, enable textured 3D landmarks.
        mapView.mapScene.enableFeatures([MapFeatures.landmarks : MapFeatureModes.landmarksTextured])
        
        defaultLocationIndicator = createDefaultLocationIndicator()
        customLocationIndicator = createCustomLocationIndicator()
        
        // We start with the built-in default LocationIndicator.
        isDefaultLocationIndicator = true
        switchToPedestrianLocationIndicator()
    }
    
    private func createDefaultLocationIndicator() -> LocationIndicator {
        let locationIndicator = LocationIndicator()
        locationIndicator.isAccuracyVisualized = true
        locationIndicator.locationIndicatorStyle = LocationIndicator.IndicatorStyle.pedestrian
        defaultHaloColor = locationIndicator.getHaloColor(locationIndicator.locationIndicatorStyle)
        return locationIndicator
    }
    
    private func createCustomLocationIndicator() -> LocationIndicator {
        // Create an "assets" directory and add the folder with content via drag & drop.
        // Adjust file name and path as appropriate for your project.
        let pedGeometryFile = getResourceStringFromBundle(fileName: "custom_location_indicator_pedestrian", type: "obj")
        let pedTextureFile = getResourceStringFromBundle(fileName: "custom_location_indicator_pedestrian", type: "png")
        let pedestrianMapMarker3DModel = MapMarker3DModel(geometryFilePath: pedGeometryFile,
                                                          textureFilePath: pedTextureFile)

        let navGeometryFile = getResourceStringFromBundle(fileName: "custom_location_indicator_navigation", type: "obj")
        let navTextureFile = getResourceStringFromBundle(fileName: "custom_location_indicator_navigation", type: "png")
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
        
        locationIndicator.isAccuracyVisualized = true
        locationIndicator.locationIndicatorStyle = LocationIndicator.IndicatorStyle.pedestrian
        
        return locationIndicator
    }

    private func getResourceStringFromBundle(fileName: String, type: String) -> String {
        let bundle = Bundle.main
        guard let resourceUrl = bundle.url(forResource: fileName, withExtension: type) else {
            fatalError("Error: Resource not found!")
        }

        return resourceUrl.path
    }
    
    // Calculate a fixed route for testing and start guidance simulation along the route.
    func startButtonClicked() {
        if visualNavigator.isRendering {
            return;
        }

        let startWaypoint = Waypoint(coordinates: getLastKnownLocation().coordinates)
        let destinationWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: 52.530905, longitude: 13.385007))

        routingEngine.calculateRoute(with: [startWaypoint, destinationWaypoint],
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
    func stopButtonClicked() {
        stopGuidance()
    }

    // Toggle between the default LocationIndicator and custom LocationIndicator.
    // The default LocationIndicator uses a 3D asset that is part of the HERE SDK.
    // The custom LocationIndicator uses different 3D assets, see asset folder.
    func toggleStyleButtonClicked() {
        // Toggle state.
        isDefaultLocationIndicator = !isDefaultLocationIndicator

        // Select pedestrian or navigation assets.
        if visualNavigator.isRendering {
            switchToNavigationLocationIndicator()
        } else {
            switchToPedestrianLocationIndicator()
        }
    }
    
    // Toggle the halo color of the default and custom LocationIndicator.
    func togglehaloColorButtonClicked() {
        // Toggle state.
        isCustomHaloColor = !isCustomHaloColor
        setSelectedHaloColor()
    }
    
    private func setSelectedHaloColor() {
        if isCustomHaloColor {
            let customHaloColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.3)
            defaultLocationIndicator.setHaloColor(defaultLocationIndicator.locationIndicatorStyle, color: customHaloColor)
            customLocationIndicator.setHaloColor(customLocationIndicator.locationIndicatorStyle, color: customHaloColor)
        } else {
            defaultLocationIndicator.setHaloColor(defaultLocationIndicator.locationIndicatorStyle, color: defaultHaloColor)
            customLocationIndicator.setHaloColor(customLocationIndicator.locationIndicatorStyle, color: defaultHaloColor)
        }
    }
    
    private func switchToPedestrianLocationIndicator() {
        if isDefaultLocationIndicator {
            defaultLocationIndicator.enable(for: mapView)
            defaultLocationIndicator.locationIndicatorStyle = LocationIndicator.IndicatorStyle.pedestrian
            customLocationIndicator.disable()
        } else {
            defaultLocationIndicator.disable();
            customLocationIndicator.enable(for: mapView);
            customLocationIndicator.locationIndicatorStyle = LocationIndicator.IndicatorStyle.pedestrian
        }
        
        // Set last location from LocationSimulator.
        defaultLocationIndicator.updateLocation(getLastKnownLocation())
        customLocationIndicator.updateLocation(getLastKnownLocation())
        
        setSelectedHaloColor()
    }

    private func switchToNavigationLocationIndicator() {
        if isDefaultLocationIndicator {
            // By default, the VisualNavigator adds a LocationIndicator on its own.
            // This can be kept by calling visualNavigator.customLocationIndicator = nil
            // However, here we want to be able to customize the halo for the default location indicator.
            // Therefore, we still need to set our own instance to the VisualNavigator.
            customLocationIndicator.disable()
            defaultLocationIndicator.enable(for: mapView)
            defaultLocationIndicator.locationIndicatorStyle = LocationIndicator.IndicatorStyle.navigation
            visualNavigator.customLocationIndicator = defaultLocationIndicator
        } else {
            defaultLocationIndicator.disable()
            customLocationIndicator.enable(for: mapView)
            customLocationIndicator.locationIndicatorStyle = LocationIndicator.IndicatorStyle.navigation
            visualNavigator.customLocationIndicator = customLocationIndicator
            
            // Note that the type of the LocationIndicator is taken from the route's TransportMode.
            // It cannot be overriden during guidance.
            // During tracking mode (not shown in this app) you can specify the marker type via:
            // visualNavigator?.trackingTransportMode = .pedestrian
        }
        
        // By default, during navigation the location of the indicator is controlled by the VisualNavigator.
        
        setSelectedHaloColor()
    }
    
    private func getLastKnownLocation() -> Location {
        if lastKnownLocation == nil {
            // A LocationIndicator is intended to mark the user's current location,
            // including a bearing direction.
            // For testing purposes, we create below a Location object. Usually, you want to get this from
            // a GPS sensor instead. Check the Positioning example app for this.
            var location = Location(coordinates: routeStartGeoCoordinates)
            location.time = Date()
            location.horizontalAccuracyInMeters = defaultHaloAccurarcyInMeters
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
        let tiltInDegrees: Double = cameraTiltInDegrees
        let orientationUpdate = GeoOrientationUpdate(bearing: bearingInDegrees, tilt: tiltInDegrees)
        
        let distanceInMeters: Double = cameraDistanceInMeters
        let mapMeasure = MapMeasure(kind: .distanceInMeters, value: distanceInMeters)

        let durationInSeconds: TimeInterval = 3
        let animation = MapCameraAnimationFactory.flyTo(target: geoCoordinatesUpdate,
                                                        orientation: orientationUpdate,
                                                        zoom: mapMeasure,
                                                        bowFactor: 1,
                                                        duration: durationInSeconds)
        mapView.camera.startAnimation(animation, animationDelegate: self)
    }

    // Conforming to AnimationDelegate.
    func onAnimationStateChanged(state: heresdk.AnimationState) {
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
        
        let mapMeasure = MapMeasure(kind: .distanceInMeters, value: distanceInMeters)

        let durationInSeconds: TimeInterval = 3
        let animation = MapCameraAnimationFactory.flyTo(target: geoCoordinatesUpdate,
                                                        orientation: orientationUpdate,
                                                        zoom: mapMeasure,
                                                        bowFactor: 1,
                                                        duration: durationInSeconds)
        mapView.camera.startAnimation(animation)
    }
    
    private func startGuidance(route: Route) {
        if visualNavigator.isRendering {
            return
        }
        
        // Set the route and maneuver arrow color.
        customizeVisualNavigatorColors()

        // Set custom guidance perspective.
        customizeGuidanceView()

        // This enables a navigation view and adds a LocationIndicator.
        visualNavigator.startRendering(mapView: mapView)
        
        // Note: By default, when VisualNavigator starts rendering, a default LocationIndicator is added
        // by the HERE SDK automatically.
        visualNavigator.customLocationIndicator = customLocationIndicator
        switchToNavigationLocationIndicator()

        // Set a route to follow. This leaves tracking mode.
        visualNavigator.route = route

        // This app does not use real location updates. Instead it provides location updates based
        // on the geographic coordinates of a route using HERE SDK's LocationSimulator.
        startRouteSimulation(route: route)
    }

    private func stopGuidance() {
        visualNavigator.stopRendering()

        locationSimulator?.stop()

        // Note: By default, when VisualNavigator stops rendering, no LocationIndicator is visible.
        switchToPedestrianLocationIndicator()
        
        animateToDefaultMapPerspective()
    }

    private func customizeVisualNavigatorColors() {
        let routeAheadColor = UIColor.blue
        let routeBehindColor = UIColor.red
        let routeAheadOutlineColor = UIColor.yellow
        let routeBehindOutlineColor = UIColor.gray
        let maneuverArrowColor = UIColor.green

        let visualNavigatorColors = VisualNavigatorColors.dayColors()
        let routeProgressColors = RouteProgressColors(
            ahead: routeAheadColor,
            behind: routeBehindColor,
            outlineAhead: routeAheadOutlineColor,
            outlineBehind: routeBehindOutlineColor
        )

        // Sets the color used to draw maneuver arrows.
        visualNavigatorColors.maneuverArrowColor = maneuverArrowColor
        // Sets route color for a single transport mode. Other modes are kept using defaults.
        visualNavigatorColors.setRouteProgressColors(sectionTransportMode: SectionTransportMode.car, routeProgressColors: routeProgressColors)
        // Sets the adjusted colors for route progress and maneuver arrows based on the day color scheme.
        visualNavigator.colors = visualNavigatorColors
    }
    
    private func customizeGuidanceView() {
        let cameraBehavior = FixedCameraBehavior()
        
        // Set custom zoom level and tilt.
        cameraBehavior.cameraTiltInDegrees = cameraTiltInDegrees
        cameraBehavior.cameraDistanceInMeters = cameraDistanceInMeters
        // Disable North-Up mode by setting nil. Enable North-up mode by setting 0.
        // By default, North-Up mode is disabled.
        cameraBehavior.cameraBearingInDegrees = nil
        cameraBehavior.normalizedPrincipalPoint = Anchor2D(horizontal: 0.5, vertical: 0.5)

        // The CameraSettings can be updated during guidance at any time as often as desired.
        // Alternatively, set DynamicCameraBehavior to enable auto-zoom.
        visualNavigator.cameraBehavior = cameraBehavior
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
        // By default, accuracy is nil during simulation, but we want to customize the halo,
        // so we hijack the location object and add an accuracy value.
        let location = addHorizontalAccuracy(location)
        // Feed location data into the VisualNavigator.
        visualNavigator.onLocationUpdated(location)
        lastKnownLocation = location
    }
    
    private func addHorizontalAccuracy(_ simulatedLocation: Location) -> Location {
        var location = Location(coordinates: simulatedLocation.coordinates)
        location.time = simulatedLocation.time
        location.bearingInDegrees = simulatedLocation.bearingInDegrees
        location.horizontalAccuracyInMeters = defaultHaloAccurarcyInMeters
        return location
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
