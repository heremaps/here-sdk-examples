/*
* Copyright (C) 2020-2025 HERE Europe B.V.
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

public class VenueTapHandler {
    var venueEngine: VenueEngine
    var mapView: MapView
    var geometryLabel: UILabel
    var markerImage: MapImage?
    var marker: MapMarker?
    var selectedVenue: Venue?
    var selectedGeometry: VenueGeometry?
    var selectedTopology: VenueTopology?
    var isGeometryTapped: Bool = false
    var popupView: UIView!

    let selectedColor = UIColor(red: 0.282, green: 0.733, blue: 0.96, alpha: 1.0)
    let selectedOutlineColor = UIColor(red: 0.117, green: 0.666, blue: 0.921, alpha: 1.0)
    let selectedTextColor = UIColor.white
    let selectedTextOutlineColor = UIColor(red: 0.0, green: 0.51, blue: 0.764, alpha: 1.0)
    let selectedTopologyColor = UIColor(red: 0.3529, green: 0.7686, blue: 0.7569, alpha: 1.0)

    let geometryStyle: VenueGeometryStyle
    let labelStyle: VenueLabelStyle
    let topologyStyle: VenueGeometryStyle

    public init(venueEngine: VenueEngine, mapView: MapView, geometryLabel: UILabel) {
        self.venueEngine = venueEngine
        self.mapView = mapView
        self.geometryLabel = geometryLabel;

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
        
        if (selectedGeometry != nil) {
            deselectGeometry()
            selectedGeometry = nil
        }
        
        if(selectedTopology != nil) {
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
                // Otherwise try to select an another venue, if the tap point was on top of one of them.
                if let selectedVenue = venueMap.selectedVenue, let geometry = venueMap.getGeometry(position: position) {
                    selectGeometry(venue: selectedVenue, geometry: geometry, center: false)
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
    
    func getTopologyInfo(topology: VenueTopology) -> [NSAttributedString] {
        var attributedTexts = [NSAttributedString]()
        let pedestrianText = NSMutableAttributedString()
        var vehicleGroups = [VenueTopology.TopologyDirectionality: [String]]()
        var pedestrianDirectionality: VenueTopology.TopologyDirectionality?

        let directionDescriptions: [VenueTopology.TopologyDirectionality: String] = [
            .toStart: "TO_START",
            .fromStart: "FROM_START",
            .bidirectional: "BIDIRECTIONAL",
            .undefined: "UNDEFINED"
        ]

        let textStyle = NSMutableParagraphStyle()
        textStyle.alignment = .right

        let idText = NSAttributedString(string: "\(topology.identifier)", attributes: [.paragraphStyle: textStyle, .font: UIFont.boldSystemFont(ofSize: 16)])
        attributedTexts.append(idText)

        for access in topology.accessibility {
            let mode = access.mode
            let imageName: String
            
            switch mode {
            case .auto:
                imageName = "img_car"
            case .taxi:
                imageName = "img_taxi"
            case .motorcycle:
                imageName = "img_bike"
            case .emergencyVehicle:
                imageName = "img_ambulance"
            case .pedestrian:
                imageName = "img_pedestrian"
                pedestrianDirectionality = access.direction
            default:
                imageName = ""
            }

            if mode == .pedestrian, let image = UIImage(named: imageName) {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = image
                let imageString = NSAttributedString(attachment: imageAttachment)
                pedestrianText.append(imageString)

                let numberOfIcons = 1 // Pedestrian row always has one icon
                let spaces = getSpaces(for: numberOfIcons)
                pedestrianText.append(NSAttributedString(string: spaces))

                if let dir = pedestrianDirectionality, let description = directionDescriptions[dir] {
                    pedestrianText.append(NSAttributedString(string: description, attributes: [.paragraphStyle: textStyle]))
                }
            } else if !imageName.isEmpty {
                if vehicleGroups[access.direction] == nil {
                    vehicleGroups[access.direction] = []
                }
                vehicleGroups[access.direction]?.append(imageName)
            }
        }

        if pedestrianText.length > 0 {
            attributedTexts.append(pedestrianText)
        }

        for (direction, imageNames) in vehicleGroups {
            let vehicleText = NSMutableAttributedString()
            
            let numberOfIcons = imageNames.count
            let spaces = getSpaces(for: numberOfIcons)
            
            for imageName in imageNames {
                if let image = UIImage(named: imageName) {
                    let imageAttachment = NSTextAttachment()
                    imageAttachment.image = image
                    let imageString = NSAttributedString(attachment: imageAttachment)
                    vehicleText.append(imageString)
                    vehicleText.append(NSAttributedString(string: " "))
                }
            }

            vehicleText.append(NSAttributedString(string: spaces))

            if let description = directionDescriptions[direction] {
                vehicleText.append(NSAttributedString(string: description, attributes: [.paragraphStyle: textStyle]))
            }

            attributedTexts.append(vehicleText)
        }

        return attributedTexts
    }

    private func getSpaces(for iconCount: Int) -> String {
        switch iconCount {
        case 1:
            return String(repeating: " ", count: 33)
        case 2:
            return String(repeating: " ", count: 24)
        case 3:
            return String(repeating: " ", count: 18)
        case 4:
            return String(repeating: " ", count: 10)
        default:
            return ""
        }
    }

    public func selectTopology(venue: Venue, topology: VenueTopology, position: GeoCoordinates) {

        let attributedTexts = getTopologyInfo(topology: topology)
        deselectTopology()
        showTopologyPopup(with: attributedTexts)
        self.selectedTopology = topology
        self.selectedVenue = venue

        if (self.selectedTopology != nil) {
            selectedVenue?.setCustomStyle(topologies: [topology], style: topologyStyle)
        }
                    
        // Update the map view, if needed
        mapView.camera.lookAt(point: position)
    }
    
    func showTopologyPopup(with attributedTexts: [NSAttributedString]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let topController = windowScene.windows.first?.rootViewController else { return }

        popupView = UIView()
        popupView.backgroundColor = UIColor.white
        popupView.layer.cornerRadius = 10
        popupView.layer.shadowColor = UIColor.black.cgColor
        popupView.layer.shadowOpacity = 0.3
        popupView.layer.shadowOffset = CGSize(width: 0, height: 2)
        popupView.layer.shadowRadius = 4

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 10
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for text in attributedTexts {
            let label = UILabel()
            label.attributedText = text
            label.numberOfLines = 0
            label.textAlignment = .left

            let containerView = UIView()
            containerView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
                label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                label.topAnchor.constraint(equalTo: containerView.topAnchor),
                label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])

            stackView.addArrangedSubview(containerView)
        }

        popupView.addSubview(stackView)
        topController.view.addSubview(popupView)
        popupView.translatesAutoresizingMaskIntoConstraints = false

        let rowCount = attributedTexts.count
        let bottomConstant: CGFloat
        let baseHeight: CGFloat = 200
        let extraHeightPerRow: CGFloat = 40
        let height: CGFloat

        switch rowCount {
        case 1, 2:
            bottomConstant = -130
            height = baseHeight
        case 3:
            bottomConstant = -90
            height = baseHeight
        case 4:
            bottomConstant = -50
            height = baseHeight
        default:
            bottomConstant = -10
            height = baseHeight + (CGFloat(rowCount - 4) * extraHeightPerRow)
        }

        NSLayoutConstraint.activate([
            popupView.leadingAnchor.constraint(equalTo: topController.view.leadingAnchor),
            popupView.trailingAnchor.constraint(equalTo: topController.view.trailingAnchor),
            popupView.bottomAnchor.constraint(equalTo: topController.view.safeAreaLayoutGuide.bottomAnchor, constant: 25),
            popupView.heightAnchor.constraint(equalToConstant: height),
            stackView.topAnchor.constraint(equalTo: popupView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: popupView.bottomAnchor, constant: bottomConstant),
            stackView.leadingAnchor.constraint(equalTo: popupView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: popupView.trailingAnchor)
        ])

        popupView.transform = CGAffineTransform(translationX: 0, y: topController.view.frame.height)
        UIView.animate(withDuration: 0.3) {
            self.popupView.transform = .identity
        }
    }


    func hidePopup() {
        guard let popupView = self.popupView else { return }
        UIView.animate(withDuration: 0.3, animations: {
            popupView.transform = CGAffineTransform(translationX: 0, y: popupView.frame.height)
        }) { _ in
            popupView.removeFromSuperview()
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
    
    func deselectTopology() {
        if let topology = self.selectedTopology {
            selectedVenue?.setCustomStyle(topologies: [topology], style: nil)
            self.selectedTopology = nil
        }
        hidePopup()
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
                || venue.selectedLevel.identifier != selectedGeometry.level.identifier {
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
