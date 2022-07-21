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
    private var cameraKeyframeTracksExample: CameraKeyframeTracksExample!
    private var routeAnimationExample: RouteAnimationExample!
    private var isMapSceneLoaded = true
    private var menuSections: [MenuSection] = []
    private let geoCoordinates = GeoCoordinates(latitude: 40.71083291395444, longitude: -74.01226399217569)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapScheme: .normalDay, completion: onLoadScene)
        
        menuSections = buildMenuSections()
    }
    
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Users of the Navigate Edition can enable textured landmarks:
        // mapView.mapScene.enableFeatures([MapFeatures.landmarks : MapFeatureModes.landmarksTextured])
        
        let distanceInMeters = MapMeasure(kind: .distance, value: 5000)
        mapView.camera.lookAt(point: geoCoordinates, zoom: distanceInMeters)
        
        // Start the examples.
        isMapSceneLoaded = true
        cameraKeyframeTracksExample = CameraKeyframeTracksExample(viewController: self, mapView: mapView)
        routeAnimationExample = RouteAnimationExample(viewController: self, mapView: mapView)
    }
    
    public override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "showMenu" {
            if let vc = segue.destination as? MenuViewController {
                vc.menuSections = menuSections
            }
        }
    }
    
    @IBAction func onMenuButtonClicked(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "showMenu", sender: nil)
    }
    
    private func onStartAnimationToRouteButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            guard let route = RouteCalculator.testRoute else {
                print("Error: Error: No route for testing ...")
                return
            }
            
            routeAnimationExample.animateToRoute(route: route)
        }
    }
    
    private func onStopAnimationToRouteButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            routeAnimationExample.stopRouteAnimation()
        }
    }
    
    private func onStartTripToNYCButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            cameraKeyframeTracksExample.startTripToNYC()
        }
    }
    
    private func onStopTripToNYCButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            cameraKeyframeTracksExample.stopTripToNYCAnimation()
        }
    }
    
    // A helper method to build drawer menu items.
    private func buildMenuSections() -> [MenuSection] {
        return [
            buildAnimateToRouteMenuSection(),
            buildTripToNYCMenuSection(),
        ]
    }
    
    private func buildAnimateToRouteMenuSection() -> MenuSection {
        return MenuSection(title: "Animate to route", items: [
            MenuItem(title: "Start Animation", onSelect: onStartAnimationToRouteButtonClicked),
            MenuItem(title: "Stop Animation", onSelect: onStopAnimationToRouteButtonClicked),
        ])
    }
    
    private func buildTripToNYCMenuSection() -> MenuSection {
        return MenuSection(title: "Trip to NYC", items: [
            MenuItem(title: "Start trip to NYC", onSelect: onStartTripToNYCButtonClicked),
            MenuItem(title: "Stop trip to NYC", onSelect: onStopTripToNYCButtonClicked)
        ])
    }
    
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}

