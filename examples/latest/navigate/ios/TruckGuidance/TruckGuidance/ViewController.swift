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

// Allow simple communication with the example class and update our UI based
// on the events we get from the visual navigator.
protocol UICallback: AnyObject {
    func onTruckSpeedLimit(speedLimit: String)
    func onCarSpeedLimit(speedLimit: String)
    func onDrivingSpeed(drivingSpeed: String)

    func onTruckRestrictionWarning(description: String)
    func onHideTruckRestrictionWarning();
}

final class ViewController: UIViewController, UICallback {

    @IBOutlet private var mapView: MapView!
    private var truckGuidance: TruckGuidanceExample!
    
    private var truckSpeedLimitView = SpeedView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    private var carSpeedLimitView = SpeedView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    private var drivingSpeedView = SpeedView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    private var truckRestrictionView = TruckRestrictionView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))

    private var isSpeedViewShown = false
    private var isTruckRestrictionViewShown = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
    }

    func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Start the example.
        truckGuidance = TruckGuidanceExample(viewController: self, mapView: mapView)
        setupUIComponents()
    }
    
    func setupUIComponents() {
        // Values taken from storyboard / IB UI.
        // Here we position the panel below the second button row.
        // For this example, as parent view we use the map view.
        let margin: CGFloat = 8
        let panelWidth = mapView!.bounds.width - margin * 2
        let panelHeight: CGFloat = 80
        let xPosition: CGFloat = margin
        let yPosition: CGFloat = 46 + 30 + margin
        
        // A view to show the current truck speed limit during guidance or tracking.
        truckSpeedLimitView.frame = CGRect(x: xPosition, y: yPosition,
                                    width: panelWidth, height: panelHeight)
        truckSpeedLimitView.setNeedsDisplay()
        truckSpeedLimitView.setLabel(label: "Truck")
        truckSpeedLimitView.setSpeedLimit(speedLimit: "n/a")
        
        // A view to show the current car speed limit during guidance or tracking.
        carSpeedLimitView.frame = CGRect(x: xPosition, y: yPosition,
                                    width: panelWidth, height: panelHeight)
        carSpeedLimitView.setNeedsDisplay()
        carSpeedLimitView.setLabel(label: "Car")
        carSpeedLimitView.setSpeedLimit(speedLimit: "n/a")
        
        // Another view to show the current driving speed.
        drivingSpeedView.frame = CGRect(x: xPosition, y: yPosition,
                                    width: panelWidth, height: panelHeight)
        drivingSpeedView.setNeedsDisplay()
        drivingSpeedView.circleColor = UIColor.white
        drivingSpeedView.setSpeedLimit(speedLimit: "n/a")
        
        // A view to show TruckRestrictionWarnings.
        truckRestrictionView.frame = CGRect(x: xPosition, y: yPosition,
                                    width: panelWidth, height: panelHeight)
        truckRestrictionView.setNeedsDisplay()
    }
    
    private func showSpeedViews() {
        if !isSpeedViewShown {
            mapView!.addSubview(truckSpeedLimitView)
            mapView!.addSubview(carSpeedLimitView)
            mapView!.addSubview(drivingSpeedView)
            isSpeedViewShown = true
        }
    }
    
    private func hideSpeedViews() {
        truckSpeedLimitView.removeFromSuperview()
        carSpeedLimitView.removeFromSuperview()
        drivingSpeedView.removeFromSuperview()
        isSpeedViewShown = false
    }
   
    private func showTruckRestrictionView() {
        if !isTruckRestrictionViewShown {
            mapView!.addSubview(truckRestrictionView)
            isTruckRestrictionViewShown = true
        }
    }
    
    private func hideTruckRestrictionView() {
        truckRestrictionView.removeFromSuperview()
        isTruckRestrictionViewShown = false
    }
    
    // Make sure this is only called when the rotation animation is completed.
    public func orientationDidChange() {
        if isSpeedViewShown {
            hideSpeedViews()
            setupUIComponents()
            showSpeedViews()
        }
        
        if isTruckRestrictionViewShown {
            hideTruckRestrictionView()
            setupUIComponents()
            showTruckRestrictionView()
        }
    }
    
    // Confrom to UICallback protocol.
    func onTruckSpeedLimit(speedLimit: String) {
        truckSpeedLimitView.setSpeedLimit(speedLimit: speedLimit)
    }
    
    // Confrom to UICallback protocol.
    func onCarSpeedLimit(speedLimit: String) {
        carSpeedLimitView.setSpeedLimit(speedLimit: speedLimit)
    }
    
    // Confrom to UICallback protocol.
    func onDrivingSpeed(drivingSpeed: String) {
        drivingSpeedView.setSpeedLimit(speedLimit: drivingSpeed)
    }
    
    // Confrom to UICallback protocol.
    func onTruckRestrictionWarning(description: String) {
        showTruckRestrictionView()
        truckRestrictionView.onTruckRestrictionWarning(description: description)
    }
    
    // Confrom to UICallback protocol.
    func onHideTruckRestrictionWarning() {
        hideTruckRestrictionView()
    }
    
    @IBAction func onShowRouteClicked(_ sender: Any) {
        truckGuidance.onShowRouteClicked()
    }

    @IBAction func onStartStopClicked(_ sender: Any) {
        truckGuidance.onStartStopClicked()
    }

    @IBAction func onClearClicked(_ sender: Any) {
        truckGuidance.onClearClicked()
    }

    @IBAction func onTrackingOnOffClicked(_ sender: Any) {
        truckGuidance.onTrackingOnOffClicked()
    }

    @IBAction func onToggleSpeedClicked(_ sender: Any) {
        truckGuidance.onToggleSpeedClicked()
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
