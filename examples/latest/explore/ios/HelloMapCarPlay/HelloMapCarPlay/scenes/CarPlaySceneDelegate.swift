/*
 * Copyright (C) 2025 HERE Europe B.V.
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

import UIKit
import CarPlay

// `CarPlaySceneDelegate` manages the lifecycle events for the CarPlay scenes.
// It is responsible for setting up the user interface in CarPlay and handling
// the transitions between different states of the application when used in a CarPlay environment.
// This class is specified in the `Info.plist` under the
// `CPTemplateApplicationSceneSessionRoleApplication` key and gets called when the app interacts with CarPlay.
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var carPlayWindow: CPWindow?
    var carPlayMapTemplate = CPMapTemplate()
    let carPlayViewController = CarPlayViewController()
    
    /// Conform to `CPTemplateApplicationSceneDelegate`, needed for CarPlay.
    /// Called when the CarPlay interface controller connects and a new window for CarPlay is created.
    /// Initializes the view controller for CarPlay and sets up the root template with necessary UI elements.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController,
                                  to window: CPWindow) {
        self.interfaceController = interfaceController
        self.carPlayWindow = window
        
        // CarPlay window has been connected. Set up the view controller for it and a map template.
        carPlayMapTemplate.leadingNavigationBarButtons = [createButton(title: "Zoom +"), createButton(title: "Zoom -")]
        interfaceController.setRootTemplate(carPlayMapTemplate, animated: true)
        // CarPlayViewController is main view controller for the provided CPWindow.
        window.rootViewController = carPlayViewController
    }
    
    /// Conform to `CPTemplateApplicationSceneDelegate`, needed for CarPlay.
    /// Called when the CarPlay interface is disconnected.
    /// Use this method to clean up resources related to the CarPlay interface.
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnect interfaceController: CPInterfaceController,
                                  from window: CPWindow) {
        // Handle disconnection from CarPlay.
    }
    
    // Helper method to create navigation buttons on the CarPlay interface.
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
}

