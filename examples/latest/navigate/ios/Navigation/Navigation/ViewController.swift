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

final class ViewController: UIViewController {

    @IBOutlet private var mapView: MapView!
    @IBOutlet private var toggleTrackingButton: UIButton!
    @IBOutlet private var messageTextView: UITextView!

    private var app: App!
    private var isMapSceneLoaded = false
    private var isToggleTrackingOn = true

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Start the app that contains the logic to calculate routes & start TBT guidance.
        self.app = App(viewController: self, mapView: self.mapView!, messageTextView: self.messageTextView!)
        self.isMapSceneLoaded = true

        // Enable traffic flows by default.
        mapView.mapScene.enableFeatures([MapFeatures.trafficFlow : MapFeatureModes.trafficFlowWithFreeFlow])
    }

    @IBAction func onAddRouteSimulatedLocationButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            app.addRouteSimulatedLocationButtonClicked()
        }
    }

    @IBAction func onAddRouteDeviceLocationButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            app.addRouteDeviceLocationButtonClicked()
        }
    }

    @IBAction func onClearMapButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            app.clearMap()
        }
    }

    @IBAction func toggleTrackingButton(_ sender: Any) {
        if isMapSceneLoaded {
            if (isToggleTrackingOn) {
                isToggleTrackingOn = false
                toggleTrackingButton.setTitle("Camera Tracking: OFF", for: .normal)
                app.disableCameraTracking()
            } else {
                isToggleTrackingOn = true
                toggleTrackingButton.setTitle("Camera Tracking: ON", for: .normal)
                app.enableCameraTracking()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}
