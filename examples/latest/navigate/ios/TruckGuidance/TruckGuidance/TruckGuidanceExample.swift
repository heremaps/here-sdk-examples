/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

// An example that shows key features for truck routing.
// It uses two navigator instances to show truck and car speed limits simultaneously.
// Note that this example does not show all truck features the HERE SDK has to offer.
class TruckGuidanceExample: TapDelegate,
                            LongPressDelegate,
                            NavigableLocationDelegate,
                            TruckRestrictionsWarningDelegate,
                            EnvironmentalZoneWarningDelegate {

    private let mapView: MapView
    private var mapMarkers: [MapMarker] = []
    private var mapPolylines: [MapPolyline] = []
    private let searchEngine: SearchEngine
    private let routingEngine: RoutingEngine
    // A route in Berlin - can be changed via longtap.
    private var startGeoCoordinates = GeoCoordinates(latitude: 52.450798, longitude: 13.449408)
    private var destinationGeoCoordinates = GeoCoordinates(latitude: 52.620798, longitude: 13.409408)
    private var startMapMarker: MapMarker!
    private var destinationMapMarker: MapMarker!
    private var changeDestination = true
    private let visualNavigator: VisualNavigator
    private let navigator: Navigator
    private var visualNavigatorDelegate: VisualNavigatorSpeedLimitDelegate?
    private var navigatorDelegate: NavigatorSpeedLimitDelegate?
    private var activeTruckRestrictionWarnings: [String] = []
    private let herePositioningSimulator: HEREPositioningSimulator
    private var simulationSpeedFactor: Double = 1
    private var lastCalculatedTruckRoute: Route?
    private var isGuidance = false
    private var isTracking = false
    private let truckGuidanceUI: TruckGuidanceUI

    // Reference to the UICallback delegate.
    private weak var uiCallback: UICallback?

    init(_ mapView: MapView) {
        self.mapView = mapView

        // Adds views programmatically to the map view.
        // This example class sends notifications to UI via callback protocoll.
        truckGuidanceUI = TruckGuidanceUI(mapView)
        uiCallback = truckGuidanceUI

        do {
            // We use the search engine to find places along a route.
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
        }

        do {
            try routingEngine = RoutingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize routing engine. Cause: \(engineInstantiationError)")
        }

        do {
            // The Visual Navigator will be used for truck navigation.
            try visualNavigator = VisualNavigator()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize VisualNavigator. Cause: \(engineInstantiationError)")
        }

        do {
            // A headless Navigator to receive car speed limits in parallel.
            // This instance is running in tracking mode for its entire lifetime.
            // By default, the navigator will receive car speed limits.
            try navigator = Navigator();
        } catch let engineInstantiationError {
            fatalError("Failed to initialize Navigator. Cause: \(engineInstantiationError)")
        }

        herePositioningSimulator = HEREPositioningSimulator()

        startMapMarker = createPOIMapMarker(geoCoordinates: startGeoCoordinates, imageName: "poi_start")
        destinationMapMarker = createPOIMapMarker(geoCoordinates: destinationGeoCoordinates, imageName: "poi_destination")
        mapView.mapScene.addMapMarker(startMapMarker)
        mapView.mapScene.addMapMarker(destinationMapMarker)

        // Create a TransportProfile instance.
        // This profile is currently only used to retrieve speed limits during tracking mode
        // when no route is set to the VisualNavigator instance.
        // This profile needs to be set only once during the lifetime of the VisualNavigator
        // instance - unless it should be updated.
        // Note that currently not all parameters are consumed, see API Reference for details.
        var transportProfile = TransportProfile()
        transportProfile.vehicleProfile = createVehicleProfile()
        visualNavigator.trackingTransportProfile = transportProfile

        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distance, value: 1000 * 90)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)

        enableLayers()
        setGestureHandlers()
        setupListeners()

        showDialog(title: "Note", message: "Do a long press to change start and destination coordinates. Map icons are pickable.")
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Add views programmatically to the map view.
        truckGuidanceUI.setupUIComponents()
        truckGuidanceUI.showSpeedViews()
        truckGuidanceUI.listenForOrientationChanges()
    }

    // An immutable struct holding the definition of a truck.
    struct MyTruckSpecs {
        static let grossWeightInKilograms: Int32 = 17000 // 17 tons
        static let heightInCentimeters: Int32 = 3 * 100 // 3 meters
        static let widthInCentimeters: Int32 = 4 * 100 // 4 meters
        // The total length including all trailers (if any).
        static let lengthInCentimeters: Int32 = 8 * 100 // 8 meters
        static let weightPerAxleInKilograms: Int32? = nil
        static let axleCount: Int32? = nil
        static let trailerCount: Int32? = nil
        static let truckType: TruckType = .straight
    }

    // Used during tracking mode.
    func createVehicleProfile() -> VehicleProfile {
        var vehicleProfile = VehicleProfile(vehicleType: .truck)
        vehicleProfile.grossWeightInKilograms = MyTruckSpecs.grossWeightInKilograms
        vehicleProfile.heightInCentimeters = MyTruckSpecs.heightInCentimeters
        // The total length including all trailers (if any).
        vehicleProfile.lengthInCentimeters = MyTruckSpecs.lengthInCentimeters
        vehicleProfile.widthInCentimeters = MyTruckSpecs.widthInCentimeters
        vehicleProfile.truckType = MyTruckSpecs.truckType
        vehicleProfile.trailerCount = MyTruckSpecs.trailerCount ?? 0
        vehicleProfile.axleCount = MyTruckSpecs.axleCount
        vehicleProfile.weightPerAxleInKilograms = MyTruckSpecs.weightPerAxleInKilograms
        return vehicleProfile
    }

    // Used for route calculation.
    func createTruckSpecifications() -> TruckSpecifications {
        var truckSpecifications = TruckSpecifications()
        // When weight is not set, possible weight restrictions will not be taken into consideration
        // for route calculation. By default, weight is not set.
        // Specify the weight including trailers and shipped goods (if any).
        truckSpecifications.grossWeightInKilograms = MyTruckSpecs.grossWeightInKilograms
        truckSpecifications.heightInCentimeters = MyTruckSpecs.heightInCentimeters
        truckSpecifications.widthInCentimeters = MyTruckSpecs.widthInCentimeters
        // The total length including all trailers (if any).
        truckSpecifications.lengthInCentimeters = MyTruckSpecs.lengthInCentimeters
        truckSpecifications.weightPerAxleInKilograms = MyTruckSpecs.weightPerAxleInKilograms
        truckSpecifications.axleCount = MyTruckSpecs.axleCount
        truckSpecifications.trailerCount = MyTruckSpecs.trailerCount
        truckSpecifications.truckType = MyTruckSpecs.truckType
        return truckSpecifications
    }

    // Enable layers that may be useful for truck drivers.
    private func enableLayers() {
        var mapFeatures = [String: String]()
        mapFeatures[MapFeatures.trafficFlow] = MapFeatureModes.trafficFlowWithFreeFlow
        mapFeatures[MapFeatures.trafficIncidents] = MapFeatureModes.defaultMode
        mapFeatures[MapFeatures.safetyCameras] = MapFeatureModes.defaultMode
        mapFeatures[MapFeatures.vehicleRestrictions] = MapFeatureModes.defaultMode
        mapFeatures[MapFeatures.environmentalZones] = MapFeatureModes.defaultMode
        mapFeatures[MapFeatures.congestionZones] = MapFeatureModes.defaultMode
        mapView.mapScene.enableFeatures(mapFeatures)
    }

    private func setGestureHandlers() {
        mapView.gestures.tapDelegate = self
        mapView.gestures.longPressDelegate = self
    }

    // Conform to TapDelegate.
    // Allows retrieving details from carto POIs including vehicleRestrictions layer
    // and traffic incidents.
    // Note that restriction icons are not directly pickable: Only the restriction lines marking
    // the affected streets are pickable, but with a larger pick rectangle,
    // also the icons will become pickable indirectly.
    func onTap(origin: heresdk.Point2D) {
        // You can also use a larger area to include multiple carto POIs.
        let rectangle2D = Rectangle2D(origin: origin, size: Size2D(width: 50, height: 50))
        // Creates a list of map content type from which the results will be picked.
        // The content type values can be mapContent, mapItems and customLayerData.
        var contentTypesToPickFrom = Array<MapScene.MapPickFilter.ContentType>();

        // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need map contents so adding the mapContent filter.
        contentTypesToPickFrom.append(MapScene.MapPickFilter.ContentType.mapContent);
        let filter = MapScene.MapPickFilter(filter: contentTypesToPickFrom);
        mapView.pick(filter: filter, inside: rectangle2D) { pickMapResult in
            guard let pickMapResult = pickMapResult else {
                // An error occurred while performing the pick operation.
                return
            }
            guard let pickMapContentResult = pickMapResult.mapContent else {
                // An error occurred while performing the pick operation.
                return
            }
            let cartoPOIList = pickMapContentResult.pickedPlaces
            let trafficPOIList = pickMapContentResult.trafficIncidents
            let vehicleRestrictionResultList = pickMapContentResult.vehicleRestrictions
            // Note that pick here only the topmost icon and ignore others that may be underneath.
            if cartoPOIList.count > 0 {
                let topmostContent = cartoPOIList[0]
                print("Carto POI picked: \(topmostContent.name), Place category: \(topmostContent.placeCategoryId)")
                // Use the search engine to retrieve more details.
                self.searchEngine.searchByPickedPlace(topmostContent, languageCode: .enUs) { searchError, place in
                    if let searchError = searchError {
                        self.showDialog(title: "Error", message: "searchPickedPlace() resulted in an error: \(searchError.rawValue)")
                        return
                    }

                    if let place = place {
                        let address = place.address.addressText
                        var categories = ""
                        for category in place.details.categories {
                            if let name = category.name {
                                categories += name + " "
                            }
                        }
                        self.showDialog(title: "Carto POI", message: "\(address). Categories: \(categories)")
                    }
                }
            }
            if trafficPOIList.count > 0 {
                let topmostContent = trafficPOIList[0]
                self.showDialog(title: "Traffic incident picked", message: "Type: \(topmostContent.type.rawValue)")
                // Optionally, you can now use the TrafficEngine to retrieve more details for this incident.
            }

            if vehicleRestrictionResultList.count > 0 {
                let topmostContent = vehicleRestrictionResultList[0]
                let lat = topmostContent.coordinates.latitude
                let lon = topmostContent.coordinates.longitude
                // Note that the text property is empty for general truck restrictions.
                self.showDialog(title: "Vehicle restriction picked", message: " Location: \(lat), \(lon).")
            }
        }
    }
    // Conform to LongPressDelegate.
    func onLongPress(state: heresdk.GestureState, origin: heresdk.Point2D) {
        guard let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin) else {
            showDialog(title: "Note", message: "Invalid GeoCoordinates.")
            return
        }

        if state == .begin {
            // Set new route start or destination geographic coordinates based on long press location.
            if changeDestination {
                destinationGeoCoordinates = geoCoordinates
                destinationMapMarker.coordinates = geoCoordinates
            } else {
                startGeoCoordinates = geoCoordinates
                startMapMarker.coordinates = geoCoordinates
            }
            // Toggle the marker that should be updated on next long press.
            changeDestination = !changeDestination
        }
    }

    private func setupListeners() {
        // Set the SpeedLimitDelegate for Navigator (to receive car speed limits)
        // and VisualNavigator (to receive truck Speed Limits).
        visualNavigatorDelegate = VisualNavigatorSpeedLimitDelegate(self)
        navigatorDelegate = NavigatorSpeedLimitDelegate(self)
        visualNavigator.speedLimitDelegate = visualNavigatorDelegate
        navigator.speedLimitDelegate = navigatorDelegate

        visualNavigator.navigableLocationDelegate = self
        visualNavigator.truckRestrictionsWarningDelegate = self
        visualNavigator.environmentalZoneWarningListenerDelegate = self

        // For more warners and events during guidance, please check the Navigation example app, available on GitHub.
    }

    // Receive speed limits for trucks.
    class VisualNavigatorSpeedLimitDelegate: SpeedLimitDelegate {
        private let truckGuidanceExample: TruckGuidanceExample
        init(_ truckGuidanceExample: TruckGuidanceExample) {
            self.truckGuidanceExample = truckGuidanceExample
        }

        // Conform to SpeedLimitDelegate protocol.
        func onSpeedLimitUpdated(_ speedLimit: heresdk.SpeedLimit) {
            // For simplicity, we use here the effective legal speed limit. More differentiated speed values,
            // for example, due to weather conditions or school zones are also available.
            // See our Developer's Guide for more details.
            if let currentSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond() {
                if currentSpeedLimit == 0 {
                    print("No speed limits on this road! Drive as fast as you feel safe ...")
                    truckGuidanceExample.uiCallback?.onTruckSpeedLimit(speedLimit: "NSL")
                } else {
                    print("Current speed limit (m/s): \(currentSpeedLimit)")
                    // For this example, we keep it simple and show speed limits only in km/h.
                    let kmh = Int(truckGuidanceExample.metersPerSecondToKilometersPerHour(currentSpeedLimit))
                    truckGuidanceExample.uiCallback?.onTruckSpeedLimit(speedLimit: "\(kmh)")
                }
            } else {
                print("Warning: Speed limits unknown, data could not be retrieved.")
                truckGuidanceExample.uiCallback?.onTruckSpeedLimit(speedLimit: "n/a")
            }
        }

    }

    // A headless navigator delegate to receive car speed limits based on the truck route navigated by VisualNavigator.
    class NavigatorSpeedLimitDelegate: SpeedLimitDelegate {
        private let truckGuidanceExample: TruckGuidanceExample
        init(_ truckGuidanceExample: TruckGuidanceExample) {
            self.truckGuidanceExample = truckGuidanceExample
        }

        // Conform to SpeedLimitDelegate protocol.
        func onSpeedLimitUpdated(_ speedLimit: heresdk.SpeedLimit) {
            if let currentSpeedLimit = speedLimit.effectiveSpeedLimitInMetersPerSecond() {
                if currentSpeedLimit == 0 {
                    print("No speed limits for cars on this road! Drive as fast as you feel safe ...")
                    truckGuidanceExample.uiCallback?.onCarSpeedLimit(speedLimit: "NSL")
                } else {
                    print("Current car speed limit (m/s): \(currentSpeedLimit)")
                    // For this example, we keep it simple and show speed limits only in km/h.
                    let kmh = Int(truckGuidanceExample.metersPerSecondToKilometersPerHour(currentSpeedLimit))
                    truckGuidanceExample.uiCallback?.onCarSpeedLimit(speedLimit: "\(kmh)")
                }
            } else {
                print("Warning: Car speed limits unknown, data could not be retrieved.")
                truckGuidanceExample.uiCallback?.onCarSpeedLimit(speedLimit: "n/a")
            }
        }
    }

    // Conform to NavigableLocationDelegate.
    // Notifies on the current map-matched location and other useful information while driving.
    func onNavigableLocationUpdated(_ navigableLocation: heresdk.NavigableLocation) {
        if let drivingSpeed = navigableLocation.originalLocation.speedInMetersPerSecond {
            // Note that we ignore speedAccuracyInMetersPerSecond here for simplicity.
            let kmh = Int(metersPerSecondToKilometersPerHour(drivingSpeed))
            uiCallback?.onDrivingSpeed(drivingSpeed: "\(kmh)")
        } else {
            uiCallback?.onDrivingSpeed(drivingSpeed: "n/a")
        }
    }

    // Conform to TruckRestrictionsWarningDelegate.
    // Notifies truck drivers on road restrictions ahead. Called whenever there is a change.
    // For example, there can be a bridge ahead not high enough to pass a big truck
    // or there can be a road ahead where the weight of the truck is beyond it's permissible weight.
    // This event notifies on truck restrictions in general,
    // so it will also deliver events, when the transport type was set to a non-truck transport type.
    // The given restrictions are based on the HERE database of the road network ahead.
    func onTruckRestrictionsWarningUpdated(_ restrictions: [heresdk.TruckRestrictionWarning]) {
        // The list is guaranteed to be non-empty.
        for truckRestrictionWarning in restrictions {
            if let timeRule = truckRestrictionWarning.timeRule,
               !timeRule.appliesTo(dateTime: Date()) {
                // For example, during a specific time period of a day, some truck restriction warnings do not apply.
                // If truckRestrictionWarning.timeRule is nil, the warning applies at anytime.
                // Note: For this example, we do not skip any restriction.
                // continue
                print("Note that this truck restriction warning currently does not apply.")
            }

            // The trailer count for which the current restriction applies.
            // If the field is 'nil', then the current restriction is valid regardless of trailer count.
            if let trailerCount = truckRestrictionWarning.trailerCount,
               let myTruckTrailerCount = MyTruckSpecs.trailerCount {
                let min: Int32 = trailerCount.min
                let max: Int32? = trailerCount.max // If not set, maximum is unbounded.
                if min > myTruckTrailerCount || (max != nil && max! < myTruckTrailerCount) {
                    // The restriction is not valid for this truck.
                    // Note: For this example, we do not skip any restriction.
                    // continue
                }
            }

            let distanceType = truckRestrictionWarning.distanceType
            if distanceType == .ahead {
                print("A TruckRestriction ahead in: \(truckRestrictionWarning.distanceInMeters) meters.")
            } else if distanceType == .reached {
                print("A TruckRestriction has been reached.")
            } else if distanceType == .passed {
                // If not preceded by a "reached" notification, this restriction was valid only for the passed location.
                print("A TruckRestriction just passed.")
            }

            // One of the following restrictions applies; if more restrictions apply at the same time,
            // they are part of another TruckRestrictionWarning element contained in the list.
            if let weightRestriction = truckRestrictionWarning.weightRestriction {
                handleWeightTruckWarning(weightRestriction: weightRestriction, distanceType: distanceType)
            } else if let dimensionRestriction = truckRestrictionWarning.dimensionRestriction {
                handleDimensionTruckWarning(dimensionRestriction: dimensionRestriction, distanceType: distanceType)
            } else {
                handleTruckRestrictions("No Trucks.", distanceType)
                print("TruckRestriction: General restriction - no trucks allowed.")
            }
        }
    }

    // Conform to EnvironmentalZoneWarningDelegate.
    func onEnvironmentalZoneWarningsUpdated(_ environmentalZonesWarnings: [heresdk.EnvironmentalZoneWarning]) {
        // The list is guaranteed to be non-empty.
        for environmentalZoneWarning in environmentalZonesWarnings {
            let distanceType = environmentalZoneWarning.distanceType
            if distanceType == .ahead {
                print("An EnvironmentalZone ahead in: \(environmentalZoneWarning.distanceInMeters) meters.")
            } else if distanceType == .reached {
                print("An EnvironmentalZone has been reached.")
            } else if distanceType == .passed {
                print("An EnvironmentalZone just passed.")
            }

            // The official name of the environmental zone (example: "Zone basse émission Bruxelles").
            let name = environmentalZoneWarning.name
            // The description of the environmental zone for the default language.
            let description = environmentalZoneWarning.description.defaultValue
            // The environmental zone ID - uniquely identifies the zone in the HERE map data.
            let zoneID = environmentalZoneWarning.zoneId
            // The website of the environmental zone, if available - nil otherwise.
            let websiteUrl = environmentalZoneWarning.websiteUrl
            print("environmentalZoneWarning: description: \(String(describing: description))")
            print("environmentalZoneWarning: name: \(name)")
            print("environmentalZoneWarning: zoneID: \(zoneID)")
            print("environmentalZoneWarning: websiteUrl: \(websiteUrl ?? "N/A")")
        }
    }

    private func handleWeightTruckWarning(weightRestriction: WeightRestriction, distanceType: DistanceType) {
        let type = weightRestriction.type
        let value = weightRestriction.valueInKilograms
        print("TruckRestriction for weight (kg): \(type.rawValue): \(value)")

        var weightType = "n/a"
        if type == .truckWeight {
            weightType = "WEIGHT"
        }
        if type == .weightPerAxle {
            weightType = "WEIGHTPA"
        }
        let weightValue = "\(getTons(Int(value)))t"
        let description = "\(weightType): \(weightValue)"
        handleTruckRestrictions(description, distanceType)
    }

    private func handleDimensionTruckWarning(dimensionRestriction: DimensionRestriction, distanceType: DistanceType) {
        // Can be either a length, width, or height restriction for a truck. For example, a height
        // restriction can apply for a tunnel.
        let type = dimensionRestriction.type
        let value = dimensionRestriction.valueInCentimeters
        print("TruckRestriction for dimension: \(type.rawValue): \(value)")

        var dimType = "n/a"
        if type == .truckHeight {
            dimType = "HEIGHT"
        }
        if type == .truckLength {
            dimType = "LENGTH"
        }
        if type == .truckWidth {
            dimType = "WIDTH"
        }
        let dimValue = "\(getMeters(Int(value)))m"
        let description = "\(dimType): \(dimValue)"
        handleTruckRestrictions(description, distanceType)
    }

    // For this example, we always show only the next restriction ahead.
    // In case there are multiple restrictions ahead,
    // the nearest one will be shown after the current one has passed by.
    private func handleTruckRestrictions(_ newDescription: String, _ distanceType: DistanceType) {
        switch distanceType {
        case .passed:
            if !activeTruckRestrictionWarnings.isEmpty {
                // Remove the oldest entry from the list that equals the description.
                if let index = activeTruckRestrictionWarnings.firstIndex(of: newDescription) {
                    activeTruckRestrictionWarnings.remove(at: index)
                } else {
                    // Should never happen.
                    fatalError("Passed a restriction that was never added.")
                }

                if activeTruckRestrictionWarnings.isEmpty {
                    // No more restrictions ahead.
                    uiCallback?.onHideTruckRestrictionWarning()
                } else {
                    // Show the next restriction ahead, which will be the first item in the list.
                    uiCallback?.onTruckRestrictionWarning(description: activeTruckRestrictionWarnings[0])
                }
            }
        case .reached:
            // We reached a restriction which is already shown, so nothing to do here.
            break
        case .ahead:
            if activeTruckRestrictionWarnings.isEmpty {
                // Show the first restriction.
                uiCallback?.onTruckRestrictionWarning(description: newDescription)
                activeTruckRestrictionWarnings.append(newDescription)
            } else {
                // Do not show the restriction yet. We'll show it when the previous restrictions have passed by.
                // Add the restriction to the end of the list.
                activeTruckRestrictionWarnings.append(newDescription)
            }
        default:
            print("Unknown distance type.")
        }
    }

    private func getTons(_ valueInKilograms: Int) -> Int {
        // Convert kilograms to tons.
        let valueInTons = Double(valueInKilograms) / 1000.0
        // Round to one digit after the decimal point.
        let roundedValue = (valueInTons * 10.0).rounded() / 10.0
        // Convert the rounded value back to an integer and return.
        return Int(roundedValue)
    }

    private func getMeters(_ valueInCentimeters: Int) -> Int {
        // Convert centimeters to meters.
        let valueInMeters = Double(valueInCentimeters) / 100.0
        // Round to one digit after the decimal point.
        let roundedValue = (valueInMeters * 10.0).rounded() / 10.0
        // Convert the rounded value back to an integer and return.
        return Int(roundedValue)
    }

    func metersPerSecondToKilometersPerHour(_ metersPerSecond: Double) -> Double {
        return metersPerSecond * 3.6
    }

    // Get the waypoint list using the last two long press points.
    func getCurrentWaypoints() -> [Waypoint] {
        let startWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: startGeoCoordinates.latitude, longitude: startGeoCoordinates.longitude))
        let destinationWaypoint = Waypoint(coordinates: GeoCoordinates(latitude: destinationGeoCoordinates.latitude, longitude: destinationGeoCoordinates.longitude))
        let waypoints = [startWaypoint, destinationWaypoint]

        print("Start Waypoint: \(startWaypoint.coordinates.latitude), \(startWaypoint.coordinates.longitude)")
        print("Destination Waypoint: \(destinationWaypoint.coordinates.latitude), \(destinationWaypoint.coordinates.longitude)")

        return waypoints
    }

    func onShowRouteClicked() {
        // Calculate a truck route with the current waypoints and truck options
        routingEngine.calculateRoute(with: getCurrentWaypoints(),
                                     truckOptions: createTruckOptions()) { (routingError, routes) in
            self.handleTruckRouteResults(routingError, routes)
        }
    }

    func onStartStopClicked() {
        if lastCalculatedTruckRoute == nil {
            showDialog(title: "Note", message: "Show a route first.")
            return
        }

        isGuidance = !isGuidance
        if isGuidance {
            // Start guidance.
            visualNavigator.route = lastCalculatedTruckRoute
            startRendering()
            showDialog(title: "Note", message: "Started guidance.")
        } else {
            // Stop guidance.
            visualNavigator.route = nil
            stopRendering()
            isTracking = false
            showDialog(title: "Note", message: "Stopped guidance.")
        }
    }

    func onTrackingOnOffClicked() {
        if lastCalculatedTruckRoute == nil {
            showDialog(title: "Note", message: "Show a route first.")
            return
        }

        isTracking = !isTracking
        if isTracking {
            // Start tracking.
            visualNavigator.route = nil
            startRendering()
            // Note that during tracking the above set TransportProfile becomes active to receive
            // suitable speed limits.
            showDialog(title: "Note", message: "Started tracking along the last calculated route.")
        } else {
            // Stop tracking.
            visualNavigator.route = nil
            stopRendering()
            isGuidance = false
            showDialog(title: "Note", message: "Stopped tracking.")
        }
    }

    func onToggleSpeedClicked() {
        // Toggle simulation speed factor.
        if simulationSpeedFactor == 1 {
            simulationSpeedFactor = 8
        } else {
            simulationSpeedFactor = 1
        }

        showDialog(title: "Note", message: "Changed simulation speed factor to \(simulationSpeedFactor). Start again to use the new value.")
    }

    private func startRendering() {
        visualNavigator.startRendering(mapView: mapView)
        herePositioningSimulator.setSpeedFactor(simulationSpeedFactor)
        herePositioningSimulator.startLocating(locationDelegate1: visualNavigator,
                                               locationDelegate2: navigator,
                                               route: lastCalculatedTruckRoute!)
    }

    private func stopRendering() {
        visualNavigator.stopRendering()
        herePositioningSimulator.stopLocating()
        uiCallback?.onDrivingSpeed(drivingSpeed: "n/a")
        uiCallback?.onTruckSpeedLimit(speedLimit: "n/a")
        uiCallback?.onCarSpeedLimit(speedLimit: "n/a")
        untiltUnrotateMap()
    }

    private func untiltUnrotateMap() {
        mapView.camera.setOrientationAtTarget(GeoOrientationUpdate(bearing: 0, tilt: 0))
    }

    private func handleTruckRouteResults(_ routingError: RoutingError?, _ routes: [Route]?) {
        if let routingError = routingError {
            showDialog(title: "Error while calculating a truck route: ", message: "\(routingError.rawValue)")
            return
        }

        // When routingError is nil, routes is guaranteed to contain at least one route.
        if let truckRoute = routes?.first {
            lastCalculatedTruckRoute = truckRoute
        }

        // Search along the route for truck amenities.
        searchAlongARoute(lastCalculatedTruckRoute!)

        if let routes = routes {
            for route in routes {
                logRouteViolations(route)
            }
        }

        showRouteOnMap(route: lastCalculatedTruckRoute!, color: UIColor(red: 0, green: 0.6, blue: 1, alpha: 1), widthInPixels: 30)
    }

    private func createTruckOptions() -> TruckOptions {
        var truckOptions = TruckOptions()
        truckOptions.routeOptions.enableTolls = true

        var avoidanceOptions = AvoidanceOptions()
        avoidanceOptions.roadFeatures = [
            .uTurns,
            .ferry,
            .dirtRoad,
            .tunnel,
            .carShuttleTrain
        ]
        // Exclude emission zones to not pollute the air in sensitive inner city areas.
        avoidanceOptions.zoneCategories = [.environmental]
        truckOptions.avoidanceOptions = avoidanceOptions
        truckOptions.truckSpecifications = createTruckSpecifications()

        return truckOptions
    }

    private func logRouteViolations(_ route: Route) {
        print("Log route violations (if any).")
        let sections = route.sections
        var sectionNr = -1
        for section in sections {
            sectionNr += 1
            for sectionNotice in section.sectionNotices {
                // For example, if code is VIOLATED_AVOID_FERRY, then the route contains a ferry, although it
                // was requested to avoid ferries in RouteOptions.AvoidanceOptions.
                print("Section \(sectionNr): This route contains the following warning: \(sectionNotice.code)")

                // Get violated truck vehicle restrictions.
                for violatedRestriction in sectionNotice.violatedRestrictions {
                    // A human-readable description of the violated restriction.
                    let cause = violatedRestriction.cause
                    print("RouteViolation cause: \(cause)")
                    // If true, the violated restriction is time-dependent.
                    let timeDependent = violatedRestriction.timeDependent
                    print("timeDependent: \(timeDependent)")
                    if let details = violatedRestriction.details {
                        // The provided TruckSpecifications or TruckOptions are violated by the below values.
                        if let maxGrossWeightInKilograms = details.maxGrossWeightInKilograms {
                            print("Section \(sectionNr): Exceeded maxGrossWeightInKilograms: \(maxGrossWeightInKilograms)")
                        }
                        if let maxWeightPerAxleInKilograms = details.maxWeightPerAxleInKilograms {
                            print("Section \(sectionNr): Exceeded maxWeightPerAxleInKilograms: \(maxWeightPerAxleInKilograms)")
                        }
                        if let maxHeightInCentimeters = details.maxHeightInCentimeters {
                            print("Section \(sectionNr): Exceeded maxHeightInCentimeters: \(maxHeightInCentimeters)")
                        }
                        if let maxWidthInCentimeters = details.maxWidthInCentimeters {
                            print("Section \(sectionNr): Exceeded maxWidthInCentimeters: \(maxWidthInCentimeters)")
                        }
                        if let maxLengthInCentimeters = details.maxLengthInCentimeters {
                            print("Section \(sectionNr): Exceeded maxLengthInCentimeters: \(maxLengthInCentimeters)")
                        }
                        if let forbiddenAxleCount = details.forbiddenAxleCount {
                            print("Section \(sectionNr): Inside of forbiddenAxleCount range: \(forbiddenAxleCount.min) - \(String(describing: forbiddenAxleCount.max))")
                        }
                        if let forbiddenTrailerCount = details.forbiddenTrailerCount {
                            print("Section \(sectionNr): Inside of forbiddenTrailerCount range: \(forbiddenTrailerCount.min) - \(String(describing: forbiddenTrailerCount.max))")
                        }
                        if let maxTunnelCategory = details.maxTunnelCategory {
                            print("Section \(sectionNr): Exceeded maxTunnelCategory: \(maxTunnelCategory.rawValue)")
                        }
                        if let forbiddenTruckType = details.forbiddenTruckType {
                            print("Section \(sectionNr): ForbiddenTruckType is required: \(forbiddenTruckType.rawValue)")
                        }
                        if let timeRule = details.timeRule {
                            print("Section \(sectionNr): Time restriction violated: \(timeRule.timeRuleString)")
                        }

                        for hazardousMaterial in details.forbiddenHazardousGoods {
                            print("Section \(sectionNr): Forbidden hazardousMaterial carried: \(hazardousMaterial.rawValue)")
                        }
                    }
                }
            }
        }
    }

    private func searchAlongARoute(_ route: Route) {
        // Not all place categories are predefined as part of the NMAPlaceCategory class.
        // Find more here: https://developer.here.com/documentation/geocoding-search-api/dev_guide/topics-places/introduction.html
        let truckParking = "700-7900-0131"
        let truckStopPlaza = "700-7900-0132"

        let placeCategoryList = [
            PlaceCategory(id: PlaceCategory.accommodation),
            PlaceCategory(id: PlaceCategory.facilitiesParking),
            PlaceCategory(id: PlaceCategory.areasAndBuildings),
            PlaceCategory(id: truckParking),
            PlaceCategory(id: truckStopPlaza)
        ]

        // We specify here that we only want to include results
        // within a max distance of xx meters from any point of the route.
        let halfWidthInMeters: Int32 = 200
        let routeVertices = route.geometry.vertices

        // The areaCenter specifies a prioritized point within the corridor.
        // You can choose any coordinate given it's closer to the route and within the corridor.
        // Following route calculation, the first relevant point is expected to be the start of the route,
        // but it can vary based on your use case.
        // For example, while travelling, you can set the current location of the user.
        let areaCenter: GeoCoordinates = routeVertices[0]
        let routeCorridor = GeoCorridor(polyline: route.geometry.vertices, halfWidthInMeters: halfWidthInMeters)
        let categoryQueryArea = CategoryQuery.Area(inCorridor: routeCorridor,near: areaCenter)
        let categoryQuery = CategoryQuery(placeCategoryList, area: categoryQueryArea)

        var searchOptions = SearchOptions()
        searchOptions.languageCode = .enUs
        searchOptions.maxItems = 30

        // Note: TruckAmenities require a custom option when searching online.
        // This is not necessary when using the OfflineSearchEngine.
        // Additionally, this feature is released as closed-alpha, meaning a license must
        // be obtained from the HERE SDK team for online searches.
        // Otherwise, a SearchError.FORBIDDEN will occur.
        _ = searchEngine.setCustomOption(name: "show", value: "truck")

        searchEngine.searchByCategory(categoryQuery, options: searchOptions, completion: { (searchError, items) in
            if let searchError = searchError {
                print("No places found along the route. Error: \(searchError)")
                return
            }

            // If error is nil, it is guaranteed that the items will not be nil.
            print("Search along route found \(items!.count) places:")
            for place in items! {
                self.logPlaceAmenities(place)
            }
        })
    }

    // Note: This is a closed-alpha feature that requires an additional license.
    // Refer to the comment in searchAlongARoute() for more details.
    private func logPlaceAmenities(_ place: Place) {
        let truckAmenities = place.details.truckAmenities
        if let truckAmenities = truckAmenities {
            print("Found place with truck amenities: \(place.title)")

            // All amenities can be true or false at the same time.
            // You can use this information like in a bitmask to visualize the possible amenities.
            print("This place hasParking: \(truckAmenities.hasParking)")
            print("This place hasSecureParking: \(truckAmenities.hasSecureParking)")
            print("This place hasCarWash: \(truckAmenities.hasCarWash)")
            print("This place hasTruckWash: \(truckAmenities.hasTruckWash)")
            print("This place hasHighCanopy: \(truckAmenities.hasHighCanopy)")
            print("This place hasIdleReductionSystem: \(truckAmenities.hasIdleReductionSystem)")
            print("This place hasTruckScales: \(truckAmenities.hasTruckScales)")
            print("This place hasPowerSupply: \(truckAmenities.hasPowerSupply)")
            print("This place hasChemicalToiletDisposal: \(truckAmenities.hasChemicalToiletDisposal)")
            print("This place hasTruckStop: \(truckAmenities.hasTruckStop)")
            print("This place hasWifi: \(truckAmenities.hasWifi)")
            print("This place hasTruckService: \(truckAmenities.hasTruckService)")
            print("This place hasShower: \(truckAmenities.hasShower)")

            if let showerCount = truckAmenities.showerCount {
                print("This place has \(showerCount) showers.")
            }
        }
    }

    private func showRouteOnMap(route: Route, color: UIColor, widthInPixels: Double) {
        let routeGeoPolyline = route.geometry
        do {
            let routeMapPolyline =  try MapPolyline(geometry: routeGeoPolyline,
                                                    representation: MapPolyline.SolidRepresentation(
                                                        lineWidth: MapMeasureDependentRenderSize(
                                                            sizeUnit: RenderSize.Unit.pixels,
                                                            size: widthInPixels),
                                                        color: color,
                                                        capShape: LineCap.round))

            mapView.mapScene.addMapPolyline(routeMapPolyline)
            mapPolylines.append(routeMapPolyline)
        } catch let error {
            fatalError("Failed to render MapPolyline. Cause: \(error)")
        }

        // Optionally, hide irrelevant icons from the vehicle restriction layer that cross our route.
        // If needed, you can block specific map content categories to customize the map view.
        // For example, to hide vehicle restriction icons, you can uncomment the following line:
        // routeMapPolyline.mapContentCategoriesToBlock = Set([MapContentCategory.vehicleRestrictionIcons])

        animateToRoute(route)
    }

    private func animateToRoute(_ route: Route) {
        // Untilt and unrotate the map.
        let bearing: Double = 0
        let tilt: Double = 0

        // We want to show the route fitting in the map view with an additional padding of 50 pixels.
        let origin:Point2D = Point2D(x: 50.0, y: 50.0)
        let sizeInPixels:Size2D = Size2D(width: mapView.viewportSize.width - 100, height: mapView.viewportSize.height - 100)
        let mapViewport:Rectangle2D = Rectangle2D(origin: origin, size: sizeInPixels)

        // Animate to the route within a duration of 3 seconds.
        let update:MapCameraUpdate = MapCameraUpdateFactory.lookAt(area: route.boundingBox, orientation: GeoOrientationUpdate(GeoOrientation(bearing: bearing, tilt: tilt)), viewRectangle: mapViewport)
        let animation: MapCameraAnimation = MapCameraAnimationFactory.createAnimation(from: update, duration: TimeInterval(3), easing: Easing(EasingFunction.inCubic))
        mapView.camera.startAnimation(animation)
    }

    public func onClearClicked() {
        clearRoute()
        clearMapMarker()
    }

    private func clearRoute() {
        for mapPolyline in mapPolylines {
            mapView.mapScene.removeMapPolyline(mapPolyline)
        }
        mapPolylines.removeAll()
    }

    private func clearMapMarker() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }
        mapMarkers.removeAll()
    }

    private func createPOIMapMarker(geoCoordinates: GeoCoordinates, imageName: String) -> MapMarker {
        guard
            let image = UIImage(named: imageName),
            let imageData = image.pngData() else {
            fatalError("Failed to find image: \(imageName)")
        }
        let anchor2D = Anchor2D(horizontal: 0.5, vertical: 1)
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png),
                                  anchor: anchor2D)
        return mapMarker
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
