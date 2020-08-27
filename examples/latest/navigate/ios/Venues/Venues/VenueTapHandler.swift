/*
* Copyright (C) 2020 HERE Europe B.V.
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

public class VenueTapHandler: TapDelegate {
    var venueEngine: VenueEngine
    var mapView: MapView
    var geometryLabel: UILabel
    var markerImage: MapImage?
    var marker: MapMarker?
    var selectedVenue: Venue?
    var selectedGeometry: VenueGeometry?

    let selectedColor = UIColor(red: 0.282, green: 0.733, blue: 0.96, alpha: 1.0)
    let selectedOutlineColor = UIColor(red: 0.117, green: 0.666, blue: 0.921, alpha: 1.0)
    let selectedTextColor = UIColor.white
    let selectedTextOutlineColor = UIColor(red: 0.0, green: 0.51, blue: 0.764, alpha: 1.0)

    let geometryStyle: VenueGeometryStyle
    let labelStyle: VenueLabelStyle

    public init(venueEngine: VenueEngine, mapView: MapView, geometryLabel: UILabel) {
        self.venueEngine = venueEngine
        self.mapView = mapView
        self.geometryLabel = geometryLabel;

        // Create geometry and label styles for the selected geometry.
        geometryStyle = VenueGeometryStyle(
            mainColor: selectedColor, outlineColor: selectedOutlineColor, outlineWidth: 1)
        labelStyle = VenueLabelStyle(
            fillColor: selectedTextColor, outlineColor: selectedTextOutlineColor, outlineWidth: 1, maxFont: 28)

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
        deselectGeometry()

        let venueMap = venueEngine.venueMap
        // Get geo coordinates of the tapped point.
        if let position = mapView.viewToGeoCoordinates(viewCoordinates: origin) {
            // If the tap point was inside a selected venue, try to pick a geometry inside.
            // Otherwise try to select an another venue, if the tap point was on top of one of them.
            if let selectedVenue = venueMap.selectedVenue, let geometry = venueMap.getGeometry(position: position) {
                selectGeometry(venue: selectedVenue, geometry: geometry, center: false)
            } else if let venue = venueMap.getVenue(position: position) {
                venueMap.selectedVenue = venue
            }
        }
    }

    public func selectGeometry(venue: Venue, geometry: VenueGeometry, center: Bool) {
        deselectGeometry()
        venue.selectedDrawing = geometry.level.drawing
        venue.selectedLevel = geometry.level
        // If the geomtry has an icon, add a map marker on top of the geometry.
        if geometry.lookupType == .icon {
            if let image = getMarkerImage() {
                marker = MapMarker(at: geometry.center,
                                   image: image,
                                   anchor: Anchor2D(horizontal: 0.5, vertical: 1.0))
                if let marker = marker {
                    mapView.mapScene.addMapMarker(marker)
                }
            }
        }

        // Set a selected style for the geometry.
        self.selectedVenue = venue
        self.selectedGeometry = geometry
        venue.setCustomStyle(geometries: [geometry], style: geometryStyle, labelStyle: labelStyle)

        // Set a geometry name to the UILabel.
        geometryLabel.text = geometry.name

        if center {
            mapView.camera.lookAt(point: geometry.center)
        }
    }

    func deselectGeometry() {
        // If the map marker is already on the screen, remove it.
        if let currentMarker = marker {
            mapView.mapScene.removeMapMarker(currentMarker)
        }

        // If there is a selected geometry, reset its style.
        if let prevGeometry = self.selectedGeometry, let prevVenue = self.selectedVenue {
            prevVenue.setCustomStyle(geometries: [prevGeometry], style: nil, labelStyle: nil)
        }

        // Reset a geometry name in the UILabel.
        geometryLabel.text = ""
    }

    func getMarkerImage() -> MapImage? {
        if let image = markerImage {
            return image
        }

        // Get an image for MapMarker.
        if let image = UIImage(named: "poi.png"), let pngData = image.pngData() {
            markerImage = MapImage(pixelData: pngData, imageFormat: .png)
        }
        return markerImage
    }

    func onLevelChanged(_ venue: Venue?) {
        if let selectedVenue = selectedVenue, let venue = venue,
            let selectedGeometry = selectedGeometry {
            if venue.venueModel.id != selectedVenue.venueModel.id
                || venue.selectedLevel.id != selectedGeometry.level.id {
                deselectGeometry()
            }
        }
    }
}

extension VenueTapHandler: VenueSelectionDelegate {
    public func onSelectedVenueChanged(deselectedVenue: Venue?, selectedVenue: Venue?) {
        self.onLevelChanged(selectedVenue)
    }
}

extension VenueTapHandler: VenueDrawingSelectionDelegate {
    public func onDrawingSelected(venue: Venue, deselectedDrawing: VenueDrawing?, selectedDrawing: VenueDrawing) {
        self.onLevelChanged(venue)
    }
}

extension VenueTapHandler: VenueLevelSelectionDelegate {
    public func onLevelSelected(venue: Venue, drawing: VenueDrawing, deselectedLevel: VenueLevel?, selectedLevel: VenueLevel) {
        self.onLevelChanged(venue)
    }
}
