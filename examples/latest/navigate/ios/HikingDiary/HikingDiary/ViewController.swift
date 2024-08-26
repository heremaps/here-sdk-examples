/*
 * Copyright (C) 2022-2024 HERE Europe B.V.
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

class ViewController: UIViewController {

    @IBOutlet private var mapView: MapView!
    private var hikingApp: HikingApp?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.topoDay, completion: onLoadScene)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let message = "For this example app, an outdoor layer from thunderforest.com is used. Without setting a valid API key, these raster tiles will show a watermark (terms of usage: https://www.thunderforest.com/terms/).\n Attribution for the outdoor layer: \n Maps © www.thunderforest.com, \n Data © www.osm.org/copyright."
        showDialog(title: "Note", message: message)
    }

    // Completion handler when loading a map scene.
    private func onLoadScene(mapError: MapError?) {
        if let error = mapError {
            print("Error: Map scene not loaded, \(error)")
        } else {
            hikingApp = HikingApp(mapView: mapView)
            enableMapFeatures()
        }
    }

    // Enhance the scene with map features suitable for hiking trips.
    private func enableMapFeatures() {
        mapView.mapScene.enableFeatures([MapFeatures.terrain: MapFeatureModes.terrain3d,
                                         MapFeatures.contours: MapFeatureModes.contoursAll,
                                         MapFeatures.buildingFootprints : MapFeatureModes.buildingFootprintsAll,
                                         MapFeatures.extrudedBuildings : MapFeatureModes.extrudedBuildingsAll,
                                         MapFeatures.landmarks : MapFeatureModes.landmarksTextured])
    }
    
    // When a custom raster outdoor layer is shown, we do not need to load hidden map features to save bandwidth.
    private func disableMapFeatures() {
        mapView.mapScene.disableFeatures([MapFeatures.terrain,
                                          MapFeatures.contours,
                                          MapFeatures.buildingFootprints,
                                          MapFeatures.extrudedBuildings,
                                          MapFeatures.landmarks])
    }
    
    @IBAction func schemaSwitch(_ sender: UISwitch) {
        if sender.isOn {
            disableMapFeatures()
            hikingApp?.enableOutdoorRasterLayer()
        } else if !sender.isOn {
            enableMapFeatures()
            hikingApp?.disableOutdoorRasterLayer()
        }
    }

    @IBAction func onEnableButtonClicked(_ sender: Any) {
        hikingApp?.onStartHikingButtonClicked()
    }

    @IBAction func onDisableButtonClicked(_ sender: Any) {
        hikingApp?.onStopHikingButtonClicked()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }

    @IBAction func onMenuButtonClicked(_ sender: UIBarButtonItem) {
        let entries = hikingApp?.getMenuEntryKeys() ?? []
        if entries.isEmpty {
            hikingApp?.setMessage("No hiking diary entries yet.")
        } else {
            performSegue(withIdentifier: "showMenu", sender: mapView)
        }
    }

    // Open the menu.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMenu" {
            let menuViewController = segue.destination as? MenuViewController

            menuViewController?.entryKeys = hikingApp?.getMenuEntryKeys() ?? []
            menuViewController?.entryText = hikingApp?.getMenuEntryDescriptions() ?? []

            menuViewController?.setSelectedIndexListener { index in
                self.hikingApp?.loadDiaryEntry(index: index)
            }

            menuViewController?.setDeletedIndexListener { index in
                self.hikingApp?.deleteDiaryEntry(index: index)
            }
        }
    }

    func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))

        present(alertController, animated: true, completion: nil)
    }

    // Close the menu.
    @IBAction func unwindToViewController(_ unwindSegue: UIStoryboardSegue) {}
}
