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

public class VenueTapHandler: ObservableObject {
    var venueEngine: VenueEngine
    var mapView: MapView
    var markerImage: MapImage?
    var marker: MapMarker?
    var selectedVenue: Venue?
    
    @Published var selectedTopology: VenueTopology?
    @Published var isTopologyTapped: Bool = false
    @Published var selectedGeometry: VenueGeometry?
    @Published var isGeometryTapped: Bool = false
    
    /// When true, geometry selection skips placing a marker (routing SDK places its own)
    var skipMarkerOnSelect: Bool = false
    
    /// Called when a level change causes deselection of geometry/topology
    var onLevelChangeDeselection: (() -> Void)?
    
    // Style colors matching UIKit version
    let selectedColor = UIColor(red: 0.282, green: 0.733, blue: 0.96, alpha: 1.0)
    let selectedOutlineColor = UIColor(red: 0.117, green: 0.666, blue: 0.921, alpha: 1.0)
    let selectedTextColor = UIColor.white
    let selectedTextOutlineColor = UIColor(red: 0.0, green: 0.51, blue: 0.764, alpha: 1.0)
    let selectedTopologyColor = UIColor(red: 0.3529, green: 0.7686, blue: 0.7569, alpha: 1.0)
    
    let geometryStyle: VenueGeometryStyle
    let labelStyle: VenueLabelStyle
    let topologyStyle: VenueGeometryStyle
    
    public init(venueEngine: VenueEngine, mapView: MapView) {
        self.venueEngine = venueEngine
        self.mapView = mapView
        
        // Create geometry and label styles for the selected geometry.
        geometryStyle = VenueGeometryStyle(
            mainColor: selectedColor, outlineColor: selectedOutlineColor, outlineWidth: 1)
        labelStyle = VenueLabelStyle(
            fillColor: selectedTextColor, outlineColor: selectedTextOutlineColor, outlineWidth: 1, maxFont: 28)
        topologyStyle = VenueGeometryStyle(
            mainColor: selectedColor, outlineColor: selectedTopologyColor, outlineWidth: 4.0)
        
        let venueMap = venueEngine.venueMap
        venueMap.addVenueSelectionDelegate(self)
        venueMap.addDrawingSelectionDelegate(self)
        venueMap.addLevelSelectionDelegate(self)
    }
    
    deinit {
        let venueMap = venueEngine.venueMap
        venueMap.removeVenueSelectionDelegate(self)
        venueMap.removeDrawingSelectionDelegate(self)
        venueMap.removeLevelSelectionDelegate(self)
    }
    
    public func onTap(origin: Point2D) {
        if selectedGeometry != nil {
            deselectGeometry()
            selectedGeometry = nil
        }
        if selectedTopology != nil {
            deselectTopology()
            selectedTopology = nil
        }
        
        let venueMap = venueEngine.venueMap
        
        // Get geo coordinates of the tapped point.
        if let position = mapView.viewToGeoCoordinates(viewCoordinates: origin) {
            if let selectedVenue = venueMap.selectedVenue, let topology = venueMap.getTopology(position: position) {
                selectTopology(venue: selectedVenue, topology: topology, position: position)
            } else {
                // If the tap point was inside a selected venue, try to pick a geometry inside.
                // Otherwise try to select another venue, if the tap point was on top of one of them.
                if let selectedVenue = venueMap.selectedVenue, let geometry = venueMap.getGeometry(position: position) {
                    selectGeometry(venue: selectedVenue, geometry: geometry, center: false, skipMarker: skipMarkerOnSelect, markerPosition: position)
                    isGeometryTapped = true
                } else if let venue = venueMap.getVenue(position: position) {
                    venueMap.selectedVenue = venue
                    isGeometryTapped = false
                } else {
                    isGeometryTapped = false
                }
            }
        }
    }
    
    public func selectGeometry(venue: Venue, geometry: VenueGeometry, center: Bool, skipMarker: Bool = false, markerPosition: GeoCoordinates? = nil) {
        deselectGeometry()
        
        // Switch to the geometry's level and drawing
        venue.selectedDrawing = geometry.level.drawing
        venue.selectedLevel = geometry.level
        
        // Add a map marker on top of the selected geometry.
        // For venues without topologies, only place marker if lookup type is icon.
        // For venues with topologies, always place marker.
        let hasTopologies = !(venue.venueModel.topologies.isEmpty)
        let shouldPlaceMarker = !skipMarker && (hasTopologies || geometry.lookupType == .icon)
        if shouldPlaceMarker, let image = getMarkerImage() {
            let position = markerPosition ?? geometry.center
            marker = MapMarker(at: position,
                               image: image,
                               anchor: Anchor2D(horizontal: 0.5, vertical: 1.0))
            if let marker = marker {
                mapView.mapScene.addMapMarker(marker)
            }
        }
        
        // Set a selected style for the geometry (skip during routing - SDK handles route visuals)
        self.selectedVenue = venue
        self.selectedGeometry = geometry
        if !skipMarker {
            venue.setCustomStyle(geometries: [geometry], style: geometryStyle, labelStyle: labelStyle)
        }
        
        isGeometryTapped = true
        
        if center {
            mapView.camera.lookAt(point: geometry.center)
        }
    }
    
    public func selectTopology(venue: Venue, topology: VenueTopology, position: GeoCoordinates) {
        deselectTopology()
        self.selectedTopology = topology
        self.selectedVenue = venue
        self.isTopologyTapped = true
        if self.selectedTopology != nil {
            selectedVenue?.setCustomStyle(topologies: [topology], style: topologyStyle)
        }
        mapView.camera.lookAt(point: position)
    }
    
    public func deselectGeometry() {
        // If the map marker is already on the screen, remove it.
        if let currentMarker = marker {
            mapView.mapScene.removeMapMarker(currentMarker)
            marker = nil
        }
        // If there is a selected geometry, reset its style.
        if let prevGeometry = self.selectedGeometry, let prevVenue = self.selectedVenue {
            prevVenue.setCustomStyle(geometries: [prevGeometry], style: nil, labelStyle: nil)
        }
        selectedGeometry = nil
        isGeometryTapped = false
    }
    
    public func deselectTopology() {
        if let topology = self.selectedTopology {
            selectedVenue?.setCustomStyle(topologies: [topology], style: nil)
            self.selectedTopology = nil
        }
        isTopologyTapped = false
    }
    
    func getMarkerImage() -> MapImage? {
        if let image = markerImage {
            return image
        }
        if let image = UIImage(named: "poi"), let pngData = image.pngData() {
            markerImage = MapImage(pixelData: pngData, imageFormat: .png)
        }
        return markerImage
    }
    
    func onLevelChanged(_ venue: Venue?) {
        if let selectedVenue = selectedVenue, let venue = venue {
            var didDeselect = false
            if let selectedGeometry = selectedGeometry {
                if venue.venueModel.id != selectedVenue.venueModel.id
                    || venue.selectedLevel.identifier != selectedGeometry.level.identifier {
                    deselectGeometry()
                    didDeselect = true
                }
            }
            if selectedTopology != nil {
                deselectTopology()
                didDeselect = true
            }
            if didDeselect {
                onLevelChangeDeselection?()
            }
        }
    }
}

// MARK: - VenueSelectionDelegate
extension VenueTapHandler: VenueSelectionDelegate {
    public func onSelectedVenueChanged(deselectedVenue: Venue?, selectedVenue: Venue?) {
        self.onLevelChanged(selectedVenue)
    }
}

// MARK: - VenueDrawingSelectionDelegate
extension VenueTapHandler: VenueDrawingSelectionDelegate {
    public func onDrawingSelected(venue: Venue, deselectedDrawing: VenueDrawing?, selectedDrawing: VenueDrawing) {
        self.onLevelChanged(venue)
    }
}

// MARK: - VenueLevelSelectionDelegate
extension VenueTapHandler: VenueLevelSelectionDelegate {
    public func onLevelSelected(venue: Venue, drawing: VenueDrawing, deselectedLevel: VenueLevel?, selectedLevel: VenueLevel) {
        self.onLevelChanged(venue)
    }
}
