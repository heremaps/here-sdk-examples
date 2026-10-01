/*
 * Copyright (C) 2020-2026 HERE Europe B.V.
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
import Combine

class IndoorMapExample: ObservableObject {
    
    private let mapView: MapView
    private var venueEngine: VenueEngine?
    private(set) var venueMap: VenueMap?
    private var venueService: VenueService?
    
    // Venue lists - matching UIKit variable names exactly
    @Published var venueMapList = [String]()      // venue identifiers
    @Published var venueNamesList = [String]()    // venue names  
    @Published var venueLoaded = false
    @Published var isLoadingVenues = true
    @Published var isLoadingSelectedVenue = false
    @Published var showAuthError = false
    @Published var authErrorMessage = ""
    @Published var moveToVenue = false
    @Published var selectedVenueName: String = ""
    @Published var hasTopologies = false
    @Published var topologyVisible = false
    
    // Space list - populated when a venue is loaded
    @Published var spacesList: [VenueGeometry] = []
    
    // Tap handler for space selection
    var venueTapHandler: VenueTapHandler?
    
    // Level switcher model
    var levelSwitcherModel = LevelSwitcherModel()
    
    // Drawing/structure switcher model
    var drawingSwitcherModel = DrawingSwitcherModel()
    
    // Indoor routing view model and handler
    var indoorRoutingViewModel = IndoorRoutingViewModel()
    var indoorRoutingHandler = IndoorRoutingHandler()
    
    private var cancellables = Set<AnyCancellable>()
    
    // Set value for hrn with your platform catalog HRN value if you want to load non default collection.
    // Watermark positioning constants
    static let watermarkHorizontalPos: Double = 0.0
    static let watermarkInitialVerticalPos: Double = 0.84
    private static let watermarkMinVertical: Double = 0.5
    private static let watermarkSheetGap: Double = 0.08
    
    private var hrn: String = "YOUR_CATALOG_HRN"
    
    init(_ mapView: MapView) {
        self.mapView = mapView
        
        // Forward objectWillChange from nested ObservableObjects
        drawingSwitcherModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        levelSwitcherModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        indoorRoutingViewModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        indoorRoutingHandler.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // Connect routing handler to view model
        indoorRoutingViewModel.indoorRoutingHandler = indoorRoutingHandler
        
        // Load the map scene
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }
    
    // Completion handler for loadScene()
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        
        // Configure the map
        let camera = mapView.camera
        let distanceInMeters: Double = 1000 * 10
        let mapMeasureZoom = MapMeasure(kind: .distanceInMeters, value: distanceInMeters)
        camera.lookAt(point: GeoCoordinates(latitude: 52.553013, longitude: 13.292189), zoom: mapMeasureZoom)
        
        // Hide the extruded building layer, so that it does not overlap with the venues.
        mapView.mapScene.disableFeatures([MapFeatures.extrudedBuildings, MapFeatures.landmarks])
        
        // Set watermark location to avoid overlap with bottom drawer
        setWatermarkLocation()
        
        // Create a venue engine object. Once the initialization is done, a completion handler will be called.
        do {
            try venueEngine = VenueEngine { [weak self] in
                self?.onVenueEngineInit()
            }
        } catch {
            print("SDK Engine not instantiated: \(error)")
        }
    }
    
    private func setWatermarkLocation() {
        mapView.setWatermarkLocation(
            anchor: Anchor2D(horizontal: IndoorMapExample.watermarkHorizontalPos,
                             vertical: IndoorMapExample.watermarkInitialVerticalPos),
            offset: Point2D(x: 0.0, y: 0.0)
        )
    }
    
    /// Repositions the watermark to stay just above the bottom drawer's top edge.
    /// The `drawerHeight` is the current height of the bottom drawer in points.
    func updateWatermarkPosition(drawerHeight: CGFloat) {
        // Use the map view's actual frame height; fall back to screen height if not yet laid out.
        var mapViewHeight = mapView.frame.height
        if mapViewHeight <= 0 {
            mapViewHeight = UIScreen.main.bounds.height
        }
        
        // The drawer's height is measured from the bottom of the screen.
        // Compute the fraction of the screen that the drawer occupies.
        let drawerFraction = drawerHeight / mapViewHeight
        
        // Position watermark just above the sheet top edge with a gap
        let desiredPos = 1.0 - drawerFraction - IndoorMapExample.watermarkSheetGap
        
        // Clamp: never above half screen (0.5), never below initial position (0.84)
        let watermarkVertical = max(IndoorMapExample.watermarkMinVertical,
                                    min(IndoorMapExample.watermarkInitialVerticalPos, desiredPos))
        
        mapView.setWatermarkLocation(
            anchor: Anchor2D(horizontal: IndoorMapExample.watermarkHorizontalPos,
                             vertical: watermarkVertical),
            offset: Point2D(x: 0.0, y: 0.0)
        )
    }
    
    /// Resets watermark to its initial position (used when drawer collapses or routing sheet dismisses).
    func resetWatermarkPosition() {
        setWatermarkLocation()
    }
    
    private func onVenueEngineInit() {
        guard let venueEngine = venueEngine else { return }
        
        // Get VenueService and VenueMap objects.
        self.venueMap = venueEngine.venueMap
        self.venueService = venueEngine.venueService
        
        // Add needed delegates.
        venueService?.addServiceDelegate(self)
        venueService?.addVenueMapDelegate(self)
        venueMap?.addVenueSelectionDelegate(self)
        venueMap?.addVenueInfoListDelegate(self)
        
        // Create tap handler for space selection
        venueTapHandler = VenueTapHandler(venueEngine: venueEngine, mapView: mapView)
        
        // Dismiss space selection view when level change causes deselection
        venueTapHandler?.onLevelChangeDeselection = { [weak self] in
            guard let self = self else { return }
            if self.indoorRoutingViewModel.currentState == .spaceSelected {
                self.indoorRoutingViewModel.closeSpaceSelection()
            }
        }
        
        // Forward tap handler changes to trigger UI updates
        venueTapHandler?.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // Set up level switcher
        levelSwitcherModel.setVenueMap(venueEngine.venueMap)
        
        // Set up drawing switcher
        drawingSwitcherModel.setVenueMap(venueEngine.venueMap)
        
        // When a structure is selected from the structure switcher, move camera to its centre
        drawingSwitcherModel.onStructureSelected = { [weak self] center in
            self?.mapView.camera.lookAt(point: center)
        }
        
        // Set up indoor routing handler
        indoorRoutingHandler.setup(venueEngine, mapView: mapView)
        
        // Set up tap gesture on the map
        mapView.gestures.tapDelegate = self
        
        // Set label text preference to display space names on the map
        venueService?.setLabeltextPreference(labelTextPref: ["OCCUPANT_NAMES", "SPACE_NAME", "INTERNAL_ADDRESS"])
        
        // Load topologies
        venueService?.loadTopologies()
        
        // Start VenueEngine. Once authentication is done, VenueEngine will start VenueService.
        // Once VenueService is initialized, onInitializationCompleted will be called.
        venueEngine.start { [weak self] error, _ in
            if let error = error {
                let reason: String
                switch error {
                case .invalidParameter:
                    reason = "Invalid parameter received"
                case .authenticationFailed:
                    reason = "Authentication failed. Check your credentials."
                case .noConnection:
                    reason = "No network connection"
                case .operationAfterDispose:
                    reason = "Operation invoked after SDK engine was disposed"
                @unknown default:
                    reason = "Unknown authentication error"
                }
                DispatchQueue.main.async {
                    self?.isLoadingVenues = false
                    self?.authErrorMessage = reason
                    self?.showAuthError = true
                }
            }
        }
    }
    
    // Deselect current venue and return to venue list view
    func deselectVenue() {
        venueLoaded = false
        selectedVenueName = ""
        hasTopologies = false
        topologyVisible = false
        isLoadingSelectedVenue = false
        indoorRoutingHandler.isCalculatingRoute = false
        spacesList = []
        venueTapHandler?.deselectGeometry()
        venueTapHandler?.deselectTopology()
        levelSwitcherModel.setup(with: nil)
        drawingSwitcherModel.setup(with: nil)
        indoorRoutingViewModel.dismiss()
        venueMap?.selectedVenue?.isTopologyVisible = false
        
        // Deselect venue from VenueMap so re-selecting it triggers the delegate again
        venueMap?.selectedVenue = nil
        
        // Reset camera to default position
        mapView.camera.lookAt(point: GeoCoordinates(latitude: 52.553013, longitude: 13.292189, altitude: 500.0))
        
        // Reset watermark to initial position
        resetWatermarkPosition()
    }
    
    // Toggle topology visibility on the selected venue
    func toggleTopology() {
        topologyVisible.toggle()
        venueMap?.selectedVenue?.isTopologyVisible = topologyVisible
        if !topologyVisible {
            venueTapHandler?.deselectTopology()
        }
    }
    
    // Select a venue by its identifier - matching UIKit's loadVenue function
    func loadVenue(venueIdentifier: String, venueName: String = "") {
        guard let venueService = venueService,
              let venueMap = venueMap else {
            return
        }
        
        guard venueService.isInitialized() else {
            print("Venue service is not initialized! Status: \(String(describing: venueEngine?.venueService.getInitStatus()))")
            return
        }
        
        print("Loading venue \(venueIdentifier).")
        moveToVenue = true
        isLoadingSelectedVenue = true
        selectedVenueName = venueName
        
        // Select venue by id
        venueMap.selectVenueAsync(venueIdentifier: venueIdentifier, completion: onVenueLoadError)
    }
    
    // Completion handler for venue operations
    private func onVenueLoadError(_ error: VenueErrorCode?) {
        guard let error = error else { return }
        
        DispatchQueue.main.async {
            self.isLoadingSelectedVenue = false
        }
        
        var errorMessage: String
        switch error {
        case .noNetwork:
            errorMessage = "The device has no internet connectivity"
        case .noMetaDataFound:
            errorMessage = "Meta data not present in platform collection catalog"
        case .hrnMissing:
            errorMessage = "HRN not provided. Please insert HRN"
        case .hrnMismatch:
            errorMessage = "HRN does not match with Auth key & secret"
        case .noDefaultCollection:
            errorMessage = "Default collection missing from platform collection catalog"
        case .mapIdNotFound:
            errorMessage = "Map ID requested is not part of the default collection"
        case .mapDataIncorrect:
            errorMessage = "Map data in collection is wrong"
        case .internalServerError:
            errorMessage = "Internal Server Error"
        case .serviceUnavailable:
            errorMessage = "Requested service is not available currently. Please try after some time"
        case .noMapInCollection:
            errorMessage = "No maps available in the collection"
        default:
            errorMessage = "Unknown Error encountered"
        }
        
        print("Venue load error: \(errorMessage)")
    }
}

// MARK: - VenueServiceDelegate
extension IndoorMapExample: VenueServiceDelegate {
    func onInitializationCompleted(result: VenueServiceInitStatus) {
        if result == .onlineSuccess {
            print("Venue Service successfully initialized.")
            // Request venue info list asynchronously - matching UIKit pattern
            venueMap?.getVenueInfoListAsync(completion: onVenueLoadError)
        } else {
            print("Venue Service failed to initialize!")
            DispatchQueue.main.async {
                self.isLoadingVenues = false
            }
        }
    }
    
    func onVenueServiceStopped() {
        print("Venue Service has stopped.")
    }
}

// MARK: - VenueSelectionDelegate
extension IndoorMapExample: VenueSelectionDelegate {
    func onSelectedVenueChanged(deselectedVenue: Venue?, selectedVenue: Venue?) {
        guard let venueModel = selectedVenue?.venueModel else {
            return
        }
        
        if moveToVenue {
            // Move camera to the selected drawing's centre with zoom to frame the venue.
            let distanceInMeters: Double = 500
            let mapMeasureZoom = MapMeasure(kind: .distanceInMeters, value: distanceInMeters)
            mapView.camera.lookAt(point: selectedVenue?.selectedDrawing.center ?? venueModel.center, zoom: mapMeasureZoom)
            moveToVenue = false
            
            DispatchQueue.main.async {
                self.venueLoaded = true
                self.isLoadingSelectedVenue = false
                self.hasTopologies = !venueModel.topologies.isEmpty
                // Load spaces list from venue geometries
                self.spacesList = venueModel.geometries
                // Set up level switcher for the loaded venue
                self.levelSwitcherModel.setup(with: selectedVenue)
                // Set up drawing switcher for the loaded venue
                self.drawingSwitcherModel.setup(with: selectedVenue)
            }
            
            print("Venue selected: \(String(describing: venueModel.id))")
        }
    }
}

// MARK: - VenueMapDelegate
extension IndoorMapExample: VenueMapDelegate {
    func onGetVenueCompleted(venueIdentifier: String, venueModel: VenueModel?, online: Bool, venueStyle: VenueStyle?) {
        if venueModel == nil {
            print("Loading of venue \(venueIdentifier) failed!")
        }
        
        // Zoom to venue level matching UIKit behavior
        mapView.camera.zoomTo(zoomLevel: 18)
        
        // Update topology visibility based on venue data
        DispatchQueue.main.async {
            if venueModel?.topologies.isEmpty == true {
                self.hasTopologies = false
            } else {
                self.hasTopologies = true
            }
        }
    }
}

// MARK: - VenueInfoListListenerDelegate
extension IndoorMapExample: VenueInfoListListenerDelegate {
    // This delegate method is called by the HERE SDK when venue info list is ready
    func onVenueInfoListLoad(venueInfoList: [VenueInfo]) {
        DispatchQueue.main.async { [self] in
            var index: Int = 0
            // Process the venue info list received from delegate callback
            for venueInfo in venueInfoList {
                print("Venue: \(venueInfo.venueName)")
                venueMapList.insert(venueInfo.venueIdentifier, at: index)
                venueNamesList.insert(venueInfo.venueName, at: index)
                index = index + 1
            }
            
            // Hide loading spinner
            isLoadingVenues = false
        }
    }
}

// MARK: - TapDelegate
extension IndoorMapExample: TapDelegate {
    public func onTap(origin: Point2D) {
        guard venueLoaded else { return }
        
        // Dismiss drawing switcher list if open (map tap should close it)
        if drawingSwitcherModel.showList {
            drawingSwitcherModel.closeList()
        }
        
        // When routing UI is active, skip placing marker on tap (SDK places route markers)
        let routingActive = indoorRoutingViewModel.currentState == .routingUI ||
                            indoorRoutingViewModel.currentState == .showSpaceList
        venueTapHandler?.skipMarkerOnSelect = routingActive
        
        venueTapHandler?.onTap(origin: origin)
        
        // If a geometry was tapped on a venue with topologies
        if let tapHandler = venueTapHandler,
           tapHandler.isGeometryTapped,
           let geometry = tapHandler.selectedGeometry,
           let venue = venueMap?.selectedVenue {
            if !venue.venueModel.topologies.isEmpty {
                // Check if routing UI is already active
                if indoorRoutingViewModel.currentState == .routingUI ||
                   indoorRoutingViewModel.currentState == .showSpaceList {
                    // Routing is active - use tapped point as departure
                    let tappedPosition = mapView.viewToGeoCoordinates(viewCoordinates: origin)
                    indoorRoutingViewModel.selectedDepartureGeometry = geometry
                    indoorRoutingViewModel.departureCoordinates = tappedPosition
                    venue.selectedLevel = geometry.level
                    if let position = tappedPosition {
                        mapView.camera.lookAt(point: position)
                    }
                    // Calculate route if both waypoints are set
                    if let destination = indoorRoutingViewModel.selectedArrivalGeometry {
                        indoorRoutingHandler.startRouting(
                            source: geometry, destination: destination,
                            sourceCoordinates: tappedPosition,
                            destinationCoordinates: indoorRoutingViewModel.arrivalCoordinates)
                    }
                    // Ensure we're in routing UI state (collapse space list if open)
                    indoorRoutingViewModel.currentState = .routingUI
                } else {
                    // Not in routing mode - show space selection view
                    indoorRoutingViewModel.showSpaceSelection(
                        geometry: geometry,
                        venue: venue,
                        mapView: mapView,
                        tapHandler: tapHandler
                    )
                }
            }
        } else {
            // If tapped outside geometry, dismiss routing UI if it was showing space selection
            if indoorRoutingViewModel.currentState == .spaceSelected {
                indoorRoutingViewModel.closeSpaceSelection()
            }
        }
        
        // Notify SwiftUI of changes
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

