/*
 * Copyright (C) 2019 HERE Europe B.V.
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

class MapOverlaysExample {

    private var mapView: MapView!
    private let mapCenterGeoCoordinates = GeoCoordinates(latitude: 52.520798, longitude: 13.409408)

    func onMapSceneLoaded(mapView: MapView) {
        self.mapView = mapView
        let camera = mapView.camera
        camera.setZoomLevel(15)

        camera.setTarget(mapCenterGeoCoordinates)
        addCircleMapMarker(geoCoordinates: mapCenterGeoCoordinates)
    }

    func onDefaultButtonClicked() {
        showMapOverlay()
    }

    func onAnchoredButtonClicked() {
        showAnchoredMapOverlay()
    }

    func onClearButtonClicked() {
        clearMap()
    }

    private func showMapOverlay() {
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        textView.textAlignment = NSTextAlignment.center
        textView.isEditable = false
        textView.backgroundColor = UIColor(red: 72/255, green: 218/255, blue: 208/255, alpha: 1)
        textView.textColor = UIColor.white
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.text = "Centered MapOverlay"

        let mapOverlay = MapOverlay(view: textView, geoCoordinates: mapCenterGeoCoordinates)
        mapView.addMapOverlay(mapOverlay)
    }

    private func showAnchoredMapOverlay() {
        let textView = UITextView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        textView.textAlignment = NSTextAlignment.center
        textView.isEditable = false
        textView.backgroundColor = UIColor(red: 0/255, green: 144/255, blue: 138/255, alpha: 1)
        textView.textColor = UIColor.white
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.text = "Anchored MapOverlay"
        textView.layer.anchorPoint = CGPoint(x: 0.5, y: 1)

        let mapOverlay = MapOverlay(view: textView, geoCoordinates: mapCenterGeoCoordinates)
        mapView.addMapOverlay(mapOverlay)
    }

    private func clearMap() {
        let mapOverlays = mapView.overlays
        for mapOverlay in mapOverlays {
            mapView.removeMapOverlay(mapOverlay)
        }
    }

    private func addCircleMapMarker(geoCoordinates: GeoCoordinates) {
        let mapMarker = MapMarker(at: geoCoordinates)
        let image = UIImage(named: "red_dot")
        let mapImage = MapImage(image!)
        mapMarker.addImage(mapImage!, style: MapMarkerImageStyle())
        mapView.mapScene.addMapMarker(mapMarker)
    }
}
