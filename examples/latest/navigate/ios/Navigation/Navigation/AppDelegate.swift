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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Usually, you need to initialize the HERE SDK only once during the lifetime of an application.
        initializeHERESDK()

        // Keeping the screen alive is essential for a car navigation app.
        UIApplication.shared.isIdleTimerDisabled = true

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

    func applicationWillTerminate(_ application: UIApplication) {
        disposeHERESDK()
    }
}
