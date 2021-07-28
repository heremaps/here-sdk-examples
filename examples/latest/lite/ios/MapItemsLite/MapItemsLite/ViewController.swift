/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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

    @IBOutlet private var mapView: MapViewLite!
    private var mapItemsExample: MapItemsExample!
    private var mapObjectsExample: MapObjectsExample!
    private var isMapSceneLoaded = false
    private var menuSections: [MenuSection] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map style to render the map with.
        mapView.mapScene.loadScene(mapStyle: .normalDay, callback: onLoadScene)

        menuSections = buildMenuSections()
    }

    func onLoadScene(errorCode: MapSceneLite.ErrorCode?) {
        guard errorCode == nil else {
            print("Error: Map scene not loaded, \(String(describing: errorCode))")
            return
        }

        // Start the example.
        mapItemsExample = MapItemsExample(viewController: self, mapView: mapView)
        mapObjectsExample = MapObjectsExample(mapView: mapView)
        isMapSceneLoaded = true
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if segue.identifier == "showMenu" {
            if let vc = segue.destination as? MenuViewController {
                vc.menuSections = menuSections
            }
        }
    }

    @IBAction func onMenuButtonClicked(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "showMenu", sender: nil)
    }

    private func onAnchoredButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapItemsExample.onAnchoredButtonClicked()
        }
    }

    private func onCenteredButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapItemsExample.onCenteredButtonClicked()
        }
    }
    
    private func onMapItemPolylineClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapObjectsExample.onMapPolylineClicked()
        }
    }

    private func onMapItemPolygonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapObjectsExample.onMapPolygonClicked()
        }
    }

    private func onMapItemCircleClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapObjectsExample.onMapCircleClicked()
        }
    }

    private func onClearButtonClicked(_ sender: Any) {
        if isMapSceneLoaded {
            mapItemsExample.onClearButtonClicked()
            mapObjectsExample.onClearButtonClicked()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }

    // A helper method to build drawer menu items.
    private func buildMenuSections() -> [MenuSection] {
        return [
            buildMapMarkerMenuSection(),
            buildMapObjectMenuSection(),
            buildClearMenuSection()
        ]
    }

    private func buildMapMarkerMenuSection() -> MenuSection {
        return MenuSection(title: "Map Marker", items: [
            MenuItem(title: "Anchored (2D)", onSelect: onAnchoredButtonClicked),
            MenuItem(title: "Centered (2D)", onSelect: onCenteredButtonClicked),
        ])
    }

    private func buildMapObjectMenuSection() -> MenuSection {
        return MenuSection(title: "Map Object", items: [
            MenuItem(title: "Polyline", onSelect: onMapItemPolylineClicked),
            MenuItem(title: "Polygon", onSelect: onMapItemPolygonClicked),
            MenuItem(title: "Circle", onSelect: onMapItemCircleClicked)
        ])
    }

    private func buildClearMenuSection() -> MenuSection {
        return MenuSection(title: "", items: [
            MenuItem(title: "Clear All Map Items", onSelect: onClearButtonClicked)
        ])
    }
}
