/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

import Foundation
import heresdk

// Owns the camera behaviors used by the example and switches between them on demand.
// TransitionCameraBehavior enables automatic switching between HD and SD camera behavior during guidance.
// AutomotiveCameraBehavior uses automotive-style tracking settings and can be configured from JSON.
// Note: Both TransitionCameraBehavior and AutomotiveCameraBehavior are beta features.
// Related APIs are subject to change without a deprecation process.
class CameraBehaviors {
    private let visualNavigator: VisualNavigator
    private(set) var transitionCameraBehavior: TransitionCameraBehavior
    private(set) var automotiveCameraBehavior: AutomotiveCameraBehavior
    private(set) var activeCameraBehavior: CameraBehavior?

    init(visualNavigator: VisualNavigator) {
        self.visualNavigator = visualNavigator
        self.transitionCameraBehavior = TransitionCameraBehavior.init()

        let configJson = CameraBehaviors.loadAutomotiveConfigJson()
        print("AutomotiveCameraConfig.json loaded (\(configJson.count) chars).")
        print(configJson)
        self.automotiveCameraBehavior = try! AutomotiveCameraBehavior(configJson: configJson)
        self.automotiveCameraBehavior.activeCameraType = .tracking

        self.activeCameraBehavior = self.automotiveCameraBehavior
        self.visualNavigator.cameraBehavior = self.activeCameraBehavior
    }

    // Activates TransitionCameraBehavior for automatic switching between lane-level
    // visualization and the standard navigation view.
    // Note: TransitionCameraBehavior is a beta feature and related APIs are subject to change.
    func useTransitionCameraBehavior() {
        activeCameraBehavior = transitionCameraBehavior
        visualNavigator.cameraBehavior = activeCameraBehavior
    }

    // Activates AutomotiveCameraBehavior with tracking mode from the loaded JSON configuration.
    // Note: AutomotiveCameraBehavior is a beta feature and related APIs are subject to change.
    func useAutomotiveCameraBehavior() {
        automotiveCameraBehavior.activeCameraType = .tracking
        activeCameraBehavior = automotiveCameraBehavior
        visualNavigator.cameraBehavior = activeCameraBehavior
    }

    func isAutomotiveCameraSelected() -> Bool {
        return activeCameraBehavior === automotiveCameraBehavior
    }

    // Returns the currently selected camera behavior label for UI status.
    func getCameraBehaviorStatus() -> String {
        if activeCameraBehavior === automotiveCameraBehavior {
            return "AutomotiveCameraBehavior"
        }
        return "TransitionCameraBehavior"
    }

    private static func loadAutomotiveConfigJson() -> String {
        let path = Bundle.main.path(forResource: "AutomotiveCameraConfig", ofType: "json")!
        let content = try! String(contentsOfFile: path, encoding: .utf8)
        return content
    }
}
