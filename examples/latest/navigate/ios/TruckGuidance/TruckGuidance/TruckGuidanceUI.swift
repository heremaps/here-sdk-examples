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

// A helper class that manages views added programmatically on the map view.
class TruckGuidanceUI: UICallback {
    
    private let mapView: MapView
    
    private var truckSpeedLimitView = SpeedView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    private var carSpeedLimitView = SpeedView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    private var drivingSpeedView = SpeedView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    private var truckRestrictionView = TruckRestrictionView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))

    private var isSpeedViewShown = false
    private var isTruckRestrictionViewShown = false
    
    private var hostViewWidth: CGFloat = 0;
    private var hostViewHeight: CGFloat = 0;
    
    init(_ mapView: MapView) {
        self.mapView = mapView
    }
    
    // Confrom to UICallback protocol.
    func onTruckSpeedLimit(speedLimit: String) {
        truckSpeedLimitView.speedText = speedLimit
    }
    
    // Confrom to UICallback protocol.
    func onCarSpeedLimit(speedLimit: String) {
        carSpeedLimitView.speedText = speedLimit
    }
    
    // Confrom to UICallback protocol.
    func onDrivingSpeed(drivingSpeed: String) {
        drivingSpeedView.speedText = drivingSpeed
    }
    
    // Confrom to UICallback protocol.
    func onTruckRestrictionWarning(description: String) {
        showTruckRestrictionView()
        truckRestrictionView.restrictionDescription = description
    }
    
    // Confrom to UICallback protocol.
    func onHideTruckRestrictionWarning() {
        hideTruckRestrictionView()
    }
    
    func setupUIComponents() {
        // For this example, as parent view we use the map view.
        hostViewWidth = mapView.bounds.width
        hostViewHeight = mapView.bounds.height
        
        if (UIDevice.current.orientation.isPortrait) {
            setupUIComponents(hostViewHeight > hostViewWidth ? hostViewHeight : hostViewWidth)
        } else {
            setupUIComponents(hostViewWidth < hostViewHeight ? hostViewWidth : hostViewHeight)
        }
    }
    
    func setupUIComponents(_ hostViewHeight: CGFloat) {
        let margin: CGFloat = 8
        
        // A view to show the current truck speed limit during guidance or tracking.
        truckSpeedLimitView.x = margin
        truckSpeedLimitView.y = hostViewHeight - truckSpeedLimitView.h - margin
        truckSpeedLimitView.frame = CGRect(x: truckSpeedLimitView.x, y: truckSpeedLimitView.y,
                                           width: truckSpeedLimitView.w, height: truckSpeedLimitView.h)
        truckSpeedLimitView.setNeedsDisplay()
        truckSpeedLimitView.labelText = "Truck"

        // A view to show the current car speed limit during guidance or tracking.
        carSpeedLimitView.x = margin + truckSpeedLimitView.w + margin
        carSpeedLimitView.y = hostViewHeight - carSpeedLimitView.h - margin
        carSpeedLimitView.frame = CGRect(x: carSpeedLimitView.x, y: carSpeedLimitView.y,
                                         width: carSpeedLimitView.w, height: carSpeedLimitView.h)
        carSpeedLimitView.setNeedsDisplay()
        carSpeedLimitView.labelText = "Car"
        
        // Another view to show the current driving speed.
        drivingSpeedView.x = margin + truckSpeedLimitView.w + margin + carSpeedLimitView.w + margin
        drivingSpeedView.y = hostViewHeight - drivingSpeedView.h - margin
        drivingSpeedView.frame = CGRect(x: drivingSpeedView.x, y: drivingSpeedView.y,
                                        width: drivingSpeedView.w, height: drivingSpeedView.h)
        drivingSpeedView.setNeedsDisplay()
        drivingSpeedView.circleColor = UIColor.white

        // A view to show TruckRestrictionWarnings.
        truckRestrictionView.x = margin
        truckRestrictionView.y = hostViewHeight - truckSpeedLimitView.h - margin - truckRestrictionView.h - margin * 2
        truckRestrictionView.frame = CGRect(x: truckRestrictionView.x, y: truckRestrictionView.y,
                                            width: truckRestrictionView.w, height: truckRestrictionView.h)
        truckRestrictionView.setNeedsDisplay()
    }
    
    func showSpeedViews() {
        if !isSpeedViewShown {
            mapView.addSubview(truckSpeedLimitView)
            mapView.addSubview(carSpeedLimitView)
            mapView.addSubview(drivingSpeedView)
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
            mapView.addSubview(truckRestrictionView)
            isTruckRestrictionViewShown = true
        }
    }
    
    private func hideTruckRestrictionView() {
        truckRestrictionView.removeFromSuperview()
        isTruckRestrictionViewShown = false
    }
    
    func listenForOrientationChanges() {
        // Register for orientation change notifications.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(orientationDidChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
    }
    
    // Make sure this is only called when the rotation animation is completed.
    @objc public func orientationDidChange() {
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
}
