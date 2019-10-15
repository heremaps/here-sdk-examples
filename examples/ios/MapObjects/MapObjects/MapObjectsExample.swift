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

class MapObjectsExample {

    private var mapScene: MapScene

    private var mapPolyline: MapPolyline?
    private var mapPolygon: MapPolygon?
    private var mapCircle: MapCircle?

    init(mapView: MapViewLite) {
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
        camera.setZoomLevel(14)

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
        mapScene.addMapCircle(mapCircle!)
    }

    private func createMapPolyline() -> MapPolyline {
        let coordinates = [GeoCoordinates(latitude: 52.53032, longitude: 13.37409),
                           GeoCoordinates(latitude: 52.5309, longitude: 13.3946),
                           GeoCoordinates(latitude: 52.53894, longitude: 13.39194),
                           GeoCoordinates(latitude: 52.54014, longitude: 13.37958)]

        // We are sure that the number of vertices is greater than two, so it will not crash.
        let geoPolyline = try! GeoPolyline(vertices: coordinates)
        let mapPolylineStyle = MapPolylineStyle()
        mapPolylineStyle.setWidth(inPixels: 20)
        mapPolylineStyle.setColor(0x00908AA0, encoding: .rgba8888)
        let mapPolyline = MapPolyline(geometry: geoPolyline, style: mapPolylineStyle)

        return mapPolyline
    }

    private func createMapPolygon() -> MapPolygon {
        let coordinates = [GeoCoordinates(latitude: 52.53032, longitude: 13.37409),
                           GeoCoordinates(latitude: 52.5309, longitude: 13.3946),
                           GeoCoordinates(latitude: 52.53894, longitude: 13.39194),
                           GeoCoordinates(latitude: 52.54014, longitude: 13.37958)]

        // We are sure that the number of vertices is greater than three, so it will not crash.
        let geoPolygon = try! GeoPolygon(vertices: coordinates)
        let mapPolygonStyle = MapPolygonStyle()
        mapPolygonStyle.setFillColor(0x00908AA0, encoding: .rgba8888)
        let mapPolygon = MapPolygon(geometry: geoPolygon, style: mapPolygonStyle)

        return mapPolygon
    }

    private func createMapCircle() -> MapCircle {
        let geoCircle = GeoCircle(center: GeoCoordinates(latitude: 52.530932, longitude: 13.384915),
                                  radiusInMeters: 300)
        let mapCircleStyle = MapCircleStyle()
        mapCircleStyle.setFillColor(0x00908AA0, encoding: .rgba8888)
        let mapCircle = MapCircle(geometry: geoCircle, style: mapCircleStyle)

        return mapCircle
    }

    private func clearMap() {
        if let line = mapPolyline {
            mapScene.removeMapPolyline(line)
        }

        if let area = mapPolygon {
            mapScene.removeMapPolygon(area)
        }

        if let circle = mapCircle {
            mapScene.removeMapCircle(circle)
        }
    }
}
