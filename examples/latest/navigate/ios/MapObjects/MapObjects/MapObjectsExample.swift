/*
 * Copyright (C) 2019-2020 HERE Europe B.V.
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

class MapObjectsExample {

    private var mapScene: MapScene
    private var mapPolyline: MapPolyline?
    private var mapPolygon: MapPolygon?
    private var mapCircle: MapPolygon?

    init(mapView: MapView) {
        // Configure the map.
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.530932, longitude: 13.384915),
                      distanceInMeters: 1000 * 7)

        mapScene = mapView.mapScene
    }

    func onMapPolylineClicked() {
        clearMap()
        mapPolyline = createMapPolyline()
        mapScene.addMapPolyline(mapPolyline!)
    }

    func onMapPolygonClicked() {
        clearMap()
        mapPolygon = createMapPolygon()
        mapScene.addMapPolygon(mapPolygon!)
    }

    func onMapCircleClicked() {
        clearMap()
        mapCircle = createMapCircle()
        mapScene.addMapPolygon(mapCircle!)
    }

    func onClearButtonClicked() {
        clearMap()
    }

    private func createMapPolyline() -> MapPolyline {
        let coordinates = [GeoCoordinates(latitude: 52.53032, longitude: 13.37409),
                           GeoCoordinates(latitude: 52.5309, longitude: 13.3946),
                           GeoCoordinates(latitude: 52.53894, longitude: 13.39194),
                           GeoCoordinates(latitude: 52.54014, longitude: 13.37958)]

        // We are sure that the number of vertices is greater than two, so it will not crash.
        let geoPolyline = try! GeoPolyline(vertices: coordinates)
        let lineColor = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.63)
        let mapPolyline = MapPolyline(geometry: geoPolyline,
                                      widthInPixels: 30,
                                      color: lineColor)
        return mapPolyline
    }

    private func createMapPolygon() -> MapPolygon {
        // Note that a polygon requires a clockwise order of the coordinates.
        let coordinates = [GeoCoordinates(latitude: 52.54014, longitude: 13.37958),
                           GeoCoordinates(latitude: 52.53894, longitude: 13.39194),
                           GeoCoordinates(latitude: 52.5309, longitude: 13.3946),
                           GeoCoordinates(latitude: 52.53032, longitude: 13.37409)]

        // We are sure that the number of vertices is greater than three, so it will not crash.
        let geoPolygon = try! GeoPolygon(vertices: coordinates)
        let fillColor = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.63)
        let mapPolygon = MapPolygon(geometry: geoPolygon, color: fillColor)

        return mapPolygon
    }

    private func createMapCircle() -> MapPolygon {
        let geoCircle = GeoCircle(center: GeoCoordinates(latitude: 52.530932, longitude: 13.384915),
                                  radiusInMeters: 300.0)

        let geoPolygon = GeoPolygon(geoCircle: geoCircle)
        let fillColor = UIColor(red: 0, green: 0.56, blue: 0.54, alpha: 0.63)
        let mapPolygon = MapPolygon(geometry: geoPolygon, color: fillColor)

        return mapPolygon
    }

    private func clearMap() {
        if let line = mapPolyline {
            mapScene.removeMapPolyline(line)
        }

        if let area = mapPolygon {
            mapScene.removeMapPolygon(area)
        }

        if let circle = mapCircle {
            mapScene.removeMapPolygon(circle)
        }
    }
}
