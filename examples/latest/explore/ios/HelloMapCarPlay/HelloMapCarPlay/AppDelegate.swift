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

import CarPlay
import heresdk
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CPApplicationDelegate {

    var window: UIWindow?
    let carPlayViewController = CarPlayViewController()
    let carPlayMapTemplate = CPMapTemplate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK()

        return true
    }

    private func initializeHERESDK() {
        // Set your credentials for the HERE SDK.
        let accessKeyID = "YOUR_ACCESS_KEY_ID"
        let accessKeySecret = "YOUR_ACCESS_KEY_SECRET"
        let options = SDKOptions(accessKeyId: accessKeyID, accessKeySecret: accessKeySecret)
        do {
            try SDKNativeEngine.makeSharedInstance(options: options)
        } catch let engineInstantiationError {
            fatalError("Failed to initialize the HERE SDK. Cause: \(engineInstantiationError)")
        }
    }

    private func disposeHERESDK() {
        // Free HERE SDK resources before the application shuts down.
        // Usually, this should be called only on application termination.
        // Afterwards, the HERE SDK is no longer usable unless it is initialized again.
        SDKNativeEngine.sharedInstance = nil
    }

    // Conform to CPApplicationDelegate, needed for CarPlay.
    func application(_ application: UIApplication,
                     didConnectCarInterfaceController interfaceController: CPInterfaceController,
                     to window: CPWindow) {
        // CarPlay window has been connected. Set up the view controller for it and a map template.
        carPlayMapTemplate.leadingNavigationBarButtons = [createButton(title: "Zoom +"),
                                                          createButton(title: "Zoom -")]
        interfaceController.setRootTemplate(carPlayMapTemplate, animated: true)
        // CarPlayViewController is main view controller for the provided CPWindow.
        window.rootViewController = carPlayViewController
    }

    private func createButton(title: String) -> CPBarButton {
        let barButton = CPBarButton(type: .text) { (button) in
            if (title == "Zoom +") {
                self.carPlayViewController.zoomIn()
            } else if (title == "Zoom -") {
                self.carPlayViewController.zoomOut()
            }
        }
        barButton.title = title
        return barButton
    }

    // Conform to CPApplicationDelegate, needed for CarPlay.
    func application(_ application: UIApplication,
                     didDisconnectCarInterfaceController interfaceController: CPInterfaceController,
                     from window: CPWindow) {
        // Override point for customization when disconnecting from car interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Deinitializes map renderer and releases all of its resources.
        // All existing MapView instances will become invalid after this call.
        MapView.deinitialize()
        disposeHERESDK()
    }
}
