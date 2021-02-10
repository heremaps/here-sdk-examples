//
// Copyright (c) 2021 HERE Global B.V. and its affiliate(s).
// All rights reserved.
//
// This software and other materials contain proprietary information
// controlled by HERE and are protected by applicable copyright legislation.
// Any use and utilization of this software and other materials and
// disclosure to any third parties is conditional upon having a separate
// agreement with HERE for the access, use, utilization or disclosure of this
// software. In the absence of such agreement, the use of the software is not
// allowed.
//

import heresdk
import UIKit

public class IndoorRoutingUI: UIView {
    @IBOutlet private var view: UIView!
    @IBOutlet private var departureLabel: UILabel!
    @IBOutlet private var arrivalLabel: UILabel!
    @IBOutlet private var settingsView: UIView!
    @IBOutlet private var walkSpeedSlider: UISlider!
    private weak var venueService: VenueService?
    private weak var venueMap: VenueMap?
    private weak var mapView: MapView?
    private var routingEngine: IndoorRoutingEngine?
    private var routingController: IndoorRoutingController?
    private var departure: IndoorWaypoint?
    private var arrival: IndoorWaypoint?
    private var routeOptions: IndoorRouteOptions = IndoorRouteOptions()
    private var routeStyle: IndoorRouteStyle = IndoorRouteStyle()
    private var heightConstraint: NSLayoutConstraint?

    enum SettingsViewHeights {
        static let min: CGFloat = 80
        static let max: CGFloat = 300
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        customInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }

    func customInit() {
        let frameworkBundle = Bundle(for: IndoorRoutingUI.self)
        frameworkBundle.loadNibNamed("IndoorRoutingUI", owner: self, options: nil)
        addSubview(view)
        view.frame = bounds

        settingsView.isHidden = true
        walkSpeedSlider.minimumValue = 0.5
        walkSpeedSlider.maximumValue = 2
        walkSpeedSlider.value = 1

        isHidden = true
    }

    public func setup(_ venueEngine: VenueEngine?, mapView: MapView?, heightConstraint: NSLayoutConstraint!) {
        self.mapView = mapView
        if let venueService = venueEngine?.venueService {
            self.venueService = venueService
        }
        if let venueMap = venueEngine?.venueMap {
            self.venueMap = venueMap
        }
        self.heightConstraint = heightConstraint
        initRouting()
    }

    private func initMapMarker(name: String, anchor: Anchor2D = Anchor2D(horizontal: 0.5, vertical: 0.5)) -> MapMarker? {
        if let image = UIImage(named: name), let pngData = image.pngData() {
            let markerImage = MapImage(pixelData: pngData, imageFormat: .png)
            return MapMarker(at: GeoCoordinates(latitude: 0.0, longitude: 0.0), image: markerImage, anchor: anchor)
        }

        return nil
    }

    private func getIndoorFeatureString(feature: IndoorFeatures) -> String {
        switch feature {
        case .stairs:
            return "stairs"
        case .elevator:
            return "elevator"
        case .escalator:
            return "escalator"
        case .ramp:
            return "ramp"
        case .movingWalkway:
            return "movingWalkway"
        case .transition:
            return "transition"
        @unknown default:
            return "transition"
        }
    }

    private func initRouting() {
        if let venueMap = venueMap, let venueService = venueService, let mapView = mapView {
            routingEngine = IndoorRoutingEngine(_: venueService)
            routingController = IndoorRoutingController(_: venueMap, mapScene: mapView.mapScene)
            let middleBottomAnchor = Anchor2D(horizontal: 0.5, vertical: 1.0)

            routeStyle.startMarker = initMapMarker(name: "ic_route_start.png", anchor: middleBottomAnchor)
            routeStyle.destinationMarker = initMapMarker(name: "ic_route_end.png", anchor: middleBottomAnchor)
            routeStyle.walkMarker = initMapMarker(name: "indoor_walk.png")
            routeStyle.driveMarker = initMapMarker(name: "indoor_drive.png")

            let features = [IndoorFeatures.stairs, IndoorFeatures.elevator, IndoorFeatures.escalator, IndoorFeatures.ramp]
            for feature in features {
                let featureString = getIndoorFeatureString(feature: feature)
                let marker = initMapMarker(name: "indoor_" + featureString + ".png")
                let upMarker = initMapMarker(name: "indoor_" + featureString + "_up.png")
                let downMarker = initMapMarker(name: "indoor_" + featureString + "_down.png")
                routeStyle.setIndoorMarkersFor(
                    feature: feature, upMarker: upMarker, downMarker: downMarker, exitMarker: marker)
            }
        }
    }

    @IBAction private func onRouteButton(_ sender: Any) {
        if let departure = departure, let arrival = arrival {
            routingEngine?.calculateRoute(from: departure, to: arrival, routeOptions: routeOptions) { error, routes in
                if error == nil, let routes = routes {
                    self.routingController?.showRoute(route: routes[0], style: self.routeStyle)
                } else {
                    self.routingController?.hideRoute()
                    let alert = UIAlertController(title: "Indoor Routing", message: "Failed to calculate a route.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self.window?.rootViewController?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    @IBAction private func onSettingsButton(_ sender: Any) {
        settingsView.isHidden = !settingsView.isHidden
        if let heightConstraint = heightConstraint {
            heightConstraint.constant = settingsView.isHidden
                ? SettingsViewHeights.min
                : SettingsViewHeights.max
        }
    }

    @IBAction private func onRouteModeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            routeOptions.routeOptions.optimizationMode = .fastest
        case 1:
            routeOptions.routeOptions.optimizationMode = .shortest
        default:
            routeOptions.routeOptions.optimizationMode = .fastest
        }
    }

    @IBAction private func onTransportModeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            routeOptions.transportMode = .pedestrian
        case 1:
            routeOptions.transportMode = .car
        default:
            routeOptions.transportMode = .pedestrian
        }
    }

    @IBAction private func onWalkSpeedChanged(_ sender: UISlider) {
        routeOptions.walkSpeedInMetersPerSecond = Double(sender.value)
    }

    private func getIndoorFeature(_ tag: Int) -> IndoorFeatures {
        switch tag {
        case 0:
            return .elevator
        case 1:
            return .escalator
        case 2:
            return .stairs
        case 3:
            return .movingWalkway
        case 4:
            return .ramp
        default:
            return .transition
        }
    }

    @IBAction private func onAvoidFeatureChanged(_ sender: UISwitch) {
        let indoorFeature = getIndoorFeature(sender.tag)
        if sender.isOn {
            routeOptions.indoorAvoidanceOptions.indoorFeatures.append(indoorFeature)
        } else {
            var index = 0
            for feature in routeOptions.indoorAvoidanceOptions.indoorFeatures {
                if feature == indoorFeature {
                    break
                }
                index += 1
            }
            routeOptions.indoorAvoidanceOptions.indoorFeatures.remove(at: index)
        }
    }

    private func getIndoorWaypoint(origin: Point2D) -> IndoorWaypoint? {
        if let venueMap = venueMap, let position = mapView?.viewToGeoCoordinates(viewCoordinates: origin) {
            if let venue = venueMap.getVenue(position: position) {
                let venueModel = venue.venueModel
                if venueModel.id == venueMap.selectedVenue?.venueModel.id {
                    return IndoorWaypoint(coordinates: position, venueId: String(venueModel.id), levelId: String(venue.selectedLevel.id))
                } else {
                    venueMap.selectedVenue = venue
                    return nil
                }
            }
            return IndoorWaypoint(coordinates: position)
        }
        return nil
    }

    private func updateLabelText(_ label: UILabel, waypoint: IndoorWaypoint) {
        var text = ""
        if let venueId = waypoint.venueId, let levelId = waypoint.levelId {
            text += "VenueId:" + venueId + ", labelId:" + levelId + ". "
        }
        text += "Lat: " + String(format: "%.8f", waypoint.coordinates.latitude)
            + ", Lng: " + String(format: "%.8f", waypoint.coordinates.longitude)
        label.text = text
    }

    public func onTap(origin: Point2D) {
        if let waypoint = getIndoorWaypoint(origin: origin) {
            arrival = waypoint
            updateLabelText(arrivalLabel, waypoint: waypoint)
        }

    }
}

extension IndoorRoutingUI: LongPressDelegate {
    public func onLongPress(state: GestureState, origin: Point2D) {
        if state != .end {
            return;
        }
        if let waypoint = getIndoorWaypoint(origin: origin) {
            departure = waypoint
            updateLabelText(departureLabel, waypoint: waypoint)
        }
    }
}
