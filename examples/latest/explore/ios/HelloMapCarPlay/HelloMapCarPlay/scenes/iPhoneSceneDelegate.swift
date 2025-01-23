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

// `iPhoneSceneDelegate` manages the lifecycle events of a UI scene for the application.
// This delegate handles the setup and tear-down of the application's window and its content, responding to state transitions within the scene.
// The scene management includes creating and dismissing the window, transitioning the application between background and foreground, and
// handling configuration changes. It is specified in the `Info.plist` under the `UISceneConfigurations` key for standard iOS user interfaces.
class iPhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    /// Called when a new scene session is being created and associated with the app.
    /// This method sets up the initial content and configuration for the scene using either Storyboards or programmatically.
    ///
    /// Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    /// If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    /// This class does not imply that the connecting scene or session are new (see `application(_:configurationForConnecting:options:)`).
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = scene as? UIWindowScene else { return }
        
        // If using Storyboards
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        window?.makeKeyAndVisible()
        
        // Below is an example for SwiftUI.
        //  let window = UIWindow(windowScene: windowScene)
        //  let viewController = ViewController()  // Make sure you have a ViewController to instantiate
        //  window.rootViewController = viewController
        //  self.window = window
        //  window.makeKeyAndVisible()
    }
    
    /// Called as the scene is being released by the system.
    /// This occurs when the scene enters the background or when its session is being discarded.
    func sceneDidDisconnect(_ scene: UIScene) {
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application(_:didDiscardSceneSessions:)`).
    }
    
    /// Called when the scene has moved from an inactive state to an active state.
    /// Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Restart any tasks that were paused or not yet started while the scene was inactive.
    }
    
    /// Called when the scene will move from an active state to an inactive state.
    /// This may occur due to temporary interruptions (ex. an incoming phone call).
    func sceneWillResignActive(_ scene: UIScene) {
        // Prepare the scene for the next inactive state.
    }
    
    /// Called as the scene transitions from the background to the foreground.
    /// Use this method to undo the changes made on entering the background.
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Undo any changes made on entering the background.
    }
    
    /// Called as the scene transitions from the foreground to the background.
    /// Use this method to save data, release shared resources, and store enough scene-specific state information
    /// to restore the scene back to its current state.
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save data, release shared resources, and store enough scene-specific state information.
    }
}
