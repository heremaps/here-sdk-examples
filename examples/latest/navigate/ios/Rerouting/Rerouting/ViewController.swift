/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

protocol UICallback: AnyObject {
    func onManeuverEvent(action: ManeuverAction, message1: String, message2: String)
    func onRoadShieldEvent(roadShieldIcon: UIImage)
    func onHideRoadShieldIcon()
    func onHideManeuverPanel()
}

final class ViewController: UIViewController, UICallback {

    @IBOutlet private var mapView: MapView!
    private var reroutingExample: ReroutingExample!
    private var maneuverView = ManeuverView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    private var isManeuverViewShown = false
    
    private var maneuverIconProvider: ManeuverIconProvider!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
        
        maneuverIconProvider = ManeuverIconProvider()
        maneuverIconProvider.loadManeuverIcons()
    }

    func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Start the example.
        reroutingExample = ReroutingExample(viewController: self, mapView: mapView)
        
        // Allow simple communication with the example class and update our UI based
        // on the events we get from the visual navigator.
        reroutingExample.setUICallback(self)
        
        setupManeuverPanel()
    }
    
    private func setupManeuverPanel() {
        // Values taken from storyboard / IB UI.
        // Here we position the panel below the second button row.
        // For this example, as parent view we use the map view.
        let margin: CGFloat = 8
        let panelWidth = mapView!.bounds.width - margin * 2
        let panelHeight: CGFloat = 80
        let xPosition: CGFloat = margin
        let yPosition: CGFloat = 46 + 30 + margin
        maneuverView.frame = CGRect(x: xPosition, y: yPosition,
                                    width: panelWidth, height: panelHeight)
        maneuverView.setNeedsDisplay()
    }
    
    private func hideManeuverPanel() {
        maneuverView.removeFromSuperview()
        isManeuverViewShown = false
    }
    
    // Shows maneuver panel if not already shown.
    private func showManeuverPanel() {
        if !isManeuverViewShown {
            mapView!.addSubview(maneuverView)
            isManeuverViewShown = true
        }
    }
    
    // Make sure this is only called when the rotation animation is completed.
    public func orientationDidChange() {
        if isManeuverViewShown {
            hideManeuverPanel()
            setupManeuverPanel()
            showManeuverPanel()
        }
    }
    
    // Confrom to UICallback protocol.
    func onManeuverEvent(action: ManeuverAction, message1: String, message2: String) {
        showManeuverPanel()
        maneuverView.distanceText = message1
        maneuverView.maneuverText = message2
        maneuverView.maneuverIcon = maneuverIconProvider.getManeuverIconForAction(action)
    }

    // Confrom to UICallback protocol.
    func onRoadShieldEvent(roadShieldIcon: UIImage) {
        maneuverView.roadShieldImage = roadShieldIcon
    }

    // Confrom to UICallback protocol.
    func onHideRoadShieldIcon() {
        maneuverView.roadShieldImage = nil
    }

    // Confrom to UICallback protocol.
    func onHideManeuverPanel() {
        hideManeuverPanel()
    }
    
    @IBAction func onShowRouteButtonClicked(_ sender: Any) {
        reroutingExample.onShowRouteButtonClicked()
    }

    @IBAction func onStartStopButtonClicked(_ sender: Any) {
        reroutingExample.onStartStopButtonClicked()
    }

    @IBAction func onClearMapButtonClicked(_ sender: Any) {
        reroutingExample.onClearMapButtonClicked()
    }

    @IBAction func onDeviationPointsButtonClicked(_ sender: Any) {
        reroutingExample.onDeviationPointsButtonClicked()
    }

    @IBAction func onSpeedButtonClicked(_ sender: Any) {
        reroutingExample.onSpeedButtonClicked()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
    
    // Called when the view controller's view is about to change size due to orientation change.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // The completion block will be called when the rotation is completed.
        coordinator.animate(alongsideTransition: { (context) in
            // Rotation animation takes place ...
        }) { (context) in
            // This block will be called when the rotation is completed.
            print("Orientation change has completed!")
            self.orientationDidChange()
        }
    }
}
