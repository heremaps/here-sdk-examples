/*
* Copyright (C) 2020-2022 HERE Europe B.V.
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

class ViewController: UIViewController {
    @IBOutlet weak var viewFrame: UIView!
    @IBOutlet private weak var venueIdInput: UITextField!
    @IBOutlet private weak var venueIdLoad: UIButton!
    @IBOutlet private weak var levelSwitcher: LevelSwitcher!
    @IBOutlet private weak var drawingSwitcher: DrawingSwitcher!
    @IBOutlet private weak var geometryNameLabel: UILabel!
    @IBOutlet private weak var venueSearch: VenueSearch!
    @IBOutlet private weak var venuesManager: VenuesManager!
    @IBOutlet private weak var indoorRoutingUIConstraint: NSLayoutConstraint!

    var mapView: MapView = MapView()
    var mapScheme: MapScheme = .normalDay
    var venueEngine: VenueEngine!
    var moveToVenue: Bool = false
    var venueTapHandler: VenueTapHandler?

    // Replace "CATALOG_HRN" with your platform catalog HRN value.
    let hrn: String = "CATALOG_HRN"

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.frame = viewFrame.bounds
        viewFrame.addSubview(mapView)

        venueIdInput?.keyboardType = UIKeyboardType.numberPad
        venueIdLoad?.setTitle("loading...", for: .disabled)

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let venueMap = venueEngine.venueMap
        let venueService = venueEngine.venueService
        venueService.removeServiceDelegate(self)
        venueService.removeVenueDelegate(self)
        venueMap.removeVenueSelectionDelegate(self)
        mapView.gestures.tapDelegate = nil
        mapView.gestures.longPressDelegate = nil
    }

    // Completion handler when loading a map scene.
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Configure the map.
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.553013, longitude: 13.292189, altitude: 500.0))
        // Hide the extruded building layer, so that it does not overlap with the venues.
        mapView.mapScene.setLayerVisibility(layerName: MapScene.Layers.extrudedBuildings, visibility: VisibilityState.hidden)

        // Create a venue engine object. Once the initialization is done, a completion handler
        // will be called.
        do {
            try venueEngine = VenueEngine { [weak self] in self?.onVenueEngineInit() }
        } catch {
            print("SDK Engine not instantiated: \(error)")
        }
        
    }

    private func onVenueEngineInit() {
        // Get VenueService and VenueMap objects.
        let venueMap = venueEngine.venueMap
        let venueService = venueEngine.venueService

        // Add needed delegates.
        venueService.addServiceDelegate(self)
        venueService.addVenueDelegate(self)
        venueMap.addVenueSelectionDelegate(self)

        // Connect VenueMap to switchers, to control selected drawing and level in the UI.
        levelSwitcher.setVenueMap(venueMap)
        drawingSwitcher.setVenueMap(venueMap)

        // Create a venue tap handler and set it as default tap delegate.
        venueTapHandler = VenueTapHandler(venueEngine: venueEngine,
                                         mapView: mapView,
                                         geometryLabel: geometryNameLabel)
        venueSearch.setup(venueMap, tapHandler: venueTapHandler)
        mapView.gestures.tapDelegate = self
        venuesManager.setup(venueMap, mapView: mapView)

        // Start VenueEngine. Once authentication is done, the authentication completion handler
        // will be triggered. Afterwards, VenueEngine will start VenueService. Once VenueService
        // is initialized, VenueServiceListener.onInitializationCompleted method will be called.
        venueEngine.start(callback: {
            error, data in if let error = error {
                print("Failed to authenticate, reason: " + error.localizedDescription)
            }
        })

        // Set platform catalog HRN
        venueService.setHrn(hrn: hrn)
    }

    // Touch handler for the button which selects venues by id.
    @IBAction private func loadVenue(_ sender: Any) {
        if let text = venueIdInput.text {
            // Try to parse a venue id.
            if let id = Int32(text) {
                if venueEngine?.venueService.isInitialized() ?? false {
                    print("Loading venue \(id).")
                    // Disable the input UI while a venue loading and selection is in progress.
                    venueIdLoad?.isEnabled = false
                    moveToVenue = true
                    // Select a venue by id.
                    venueEngine?.venueMap.selectVenueAsync(venueId: id)
                } else {
                    print("Venue service is not initialized! Status: \(String(describing: venueEngine?.venueService.getInitStatus()))")
                }
            } else {
                print("Load venue id is not a number!")
            }
        }
        venueIdInput?.resignFirstResponder()
    }

    @IBAction private func onSearchTap(_ sender: Any) {
        venueSearch.isHidden = !venueSearch.isHidden
    }

    @IBAction private func onEditTap(_ sender: Any) {
        venuesManager.isHidden = !venuesManager.isHidden
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}

// Tap delegate for MapView
extension ViewController: TapDelegate {
    public func onTap(origin: Point2D) {
            // Otherwise, redirect the event to the venue tap handler.
            venueTapHandler?.onTap(origin: origin)
    }
}

// Delegate for the VenueService event.
extension ViewController: VenueServiceDelegate {
    func onInitializationCompleted(result: VenueServiceInitStatus) {
        if (result == .onlineSuccess) {
            print("Venue Service successfully initialized.")
        } else {
            print("Venue Service failed to initialize!")
        }
    }

    func onVenueServiceStopped() {
        print("Venue Service has stopped.")
    }
}

// Delegate for the venue loading event.
extension ViewController: VenueDelegate {
    func onGetVenueCompleted(venueId: Int32, venueModel: VenueModel?, online: Bool, venueStyle: VenueStyle?) {
        if venueModel == nil {
            print("Loading of venue \(venueId) failed!")
        }
    }
}

// Delegate for the venue selection event.
extension ViewController: VenueSelectionDelegate {
    func onSelectedVenueChanged(deselectedVenue: Venue?, selectedVenue: Venue?) {
        if let venueModel = selectedVenue?.venueModel {
            if moveToVenue {
                // Move camera to the selected venue.
                mapView.camera.lookAt(point: venueModel.center)
                moveToVenue = false
            }
        }
        DispatchQueue.main.async {
            self.venueIdLoad?.isEnabled = true
        }
    }
}
