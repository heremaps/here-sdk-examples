/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
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
import SwiftUI

class CustomPolygonLayersExample {

    private let mapView: MapView
    private var polygonMapLayer: MapLayer!
    private var polygonDataSource: PolygonDataSource!
    private static let MAX_GEO_COORDINATE_OFFSET = 0.5;
    private static let LATITUDE = 52.530932;
    private static let LONGITUDE = 13.384915;
    private static let MAX_RADIUS_IN_METERS = 3000.0;
    private static let ID_ATTRIBUTE_NAME = "polygon_id";
    private static let COLOR_ATTRIBUTE_NAME = "polygon_color";
    private static let LATITUDE_ATTRIBUTE_NAME = "center_latitude";
    private static let LONGITUDE_ATTRIBUTE_NAME = "center_longitude";

    // Style for layer with 'technique' equal to 'polygon', 'layer' field equal to name of
    // map layer constructed later in code and 'color' attribute govern by
    // 'polygon_color' data attribute to be able to customize/modify colors of polygons.
    // See 'Developer Guide/Style guide for custom layers' and
    // 'Developer Guide/Style techniques reference for custom layers/polygon' for more details.

    private let polygonLayerStyle = """
    {
       "styles": [
           {
               "layer": "MyPolygonDataSourceLayer",
               "technique": "polygon",
               "attr": {
                   "color": ["to-color", ["get", "polygon_color"]]
               }
            }
        ]
    }
    """

    init(_ mapView: MapView) {
        self.mapView = mapView

        mapView.camera.lookAt(point: GeoCoordinates(latitude: Self.LATITUDE, longitude: Self.LONGITUDE),
                      zoom: MapMeasure(kind: .zoomLevel, value: 9))

        let dataSourceName = "MyPolygonDataSource"
        polygonDataSource = createPolygonDataSource(dataSourceName: dataSourceName)
        polygonMapLayer = createMapLayer(dataSourceName: dataSourceName)

        addRandomPolygons(numberOfPolygons: 100);
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
    }
    
    func onEnableButtonClicked() {
        polygonMapLayer.setEnabled(true)
    }

    func onDisableButtonClicked() {
        polygonMapLayer.setEnabled(false)
    }

    private func createPolygonDataSource(dataSourceName: String) -> PolygonDataSource {
        return PolygonDataSourceBuilder(mapView.mapContext)
            .withName(dataSourceName)
            .build()
    }

    private func createMapLayer(dataSourceName: String) -> MapLayer {
        // The layer should be rendered on top of other layers .
        let priority = MapLayerPriorityBuilder().renderedLast().build()
        // And it should be visible for all zoom levels. The minimum tilt level is 0 and maximum zoom level is 23.
        let range = MapLayerVisibilityRange(minimumZoomLevel: MapCameraLimits.minTilt, maximumZoomLevel: MapCameraLimits.maxZoomLevel)

        let mapLayer: MapLayer
        do {
            // Build and add the layer to the map.
            try mapLayer = MapLayerBuilder()
                .forMap(mapView.hereMap)
                .withName(dataSourceName + "Layer")
                .withDataSource(named: dataSourceName,
                                contentType: .polygon)
                .withPriority(priority)
                .withVisibilityRange(range)
                .withStyle(JsonStyleFactory.createFromString(polygonLayerStyle))
                .build()
            return mapLayer
        } catch let InstantiationException {
            fatalError("MapLayer creation failed Cause: \(InstantiationException)")
        }
    }

    private func generateRandomCoordinates() -> GeoCoordinates {
        return GeoCoordinates(latitude: Double.random(in: -Self.MAX_GEO_COORDINATE_OFFSET...Self.MAX_GEO_COORDINATE_OFFSET)  + Self.LATITUDE,
                              longitude: Double.random(in: -Self.MAX_GEO_COORDINATE_OFFSET...Self.MAX_GEO_COORDINATE_OFFSET)  + Self.LONGITUDE)
    }

    private static func generateRandomGeoPolygon(center coordinates: GeoCoordinates) -> GeoPolygon{
        let geoCircle = GeoCircle(center: coordinates, radiusInMeters: Double.random(in: 0...Self.MAX_RADIUS_IN_METERS))
        return GeoPolygon(geoCircle: geoCircle)
     }

    private func generateRandomPolygon() -> PolygonData {
         let center = generateRandomCoordinates();
         let attributesBuilder = DataAttributesBuilder()
            .with(name: Self.ID_ATTRIBUTE_NAME, value: Int64.random(in: 0...1))
            .with(name: Self.COLOR_ATTRIBUTE_NAME, value: UIColor.random.hexString)
            .with(name: Self.LATITUDE_ATTRIBUTE_NAME, value: center.latitude)
            .with(name: Self.LONGITUDE_ATTRIBUTE_NAME, value: center.longitude)

         let polygonData = PolygonDataBuilder()
                 .withAttributes(attributesBuilder.build())
                 .withGeometry(Self.generateRandomGeoPolygon(center: center))
                 .build()
         return polygonData
     }

    public func addRandomPolygons(numberOfPolygons: Int) {
        var polygons: [PolygonData] = []
        for _ in 0..<numberOfPolygons {
            polygons.append(generateRandomPolygon())
        }
        polygonDataSource.add(polygons)
    }

    public func modifyPolygons() {
        polygonDataSource.forEach { polygonDataAccessor in
            let attributesAccessor = polygonDataAccessor.getAttributes()
            // 'process' function is executed on each item in data source so here is place to
            // perform some kind of filtering. In our case we decide, based on parity of
            // 'polygon_id' data attribute, to either modify color or geometry of item.
            let objectId = attributesAccessor.getInt64(Self.ID_ATTRIBUTE_NAME) ?? 0
            if objectId % 2 == 0 {
                // modify color
                attributesAccessor.addOrReplace(name: Self.COLOR_ATTRIBUTE_NAME, value: UIColor.random.hexString)
            } else {
                // read back polygon center
                let center = GeoCoordinates(latitude: attributesAccessor.getDouble(Self.LATITUDE_ATTRIBUTE_NAME) ?? 0.0,
                                            longitude: attributesAccessor.getDouble(Self.LONGITUDE_ATTRIBUTE_NAME) ?? 0.0)
                // set new geometry centered at previous location
                polygonDataAccessor.setGeometry(Self.generateRandomGeoPolygon(center: center))
            }

            // Return value 'True' denotes we want to keep processing subsequent items in data
            // source. In case of performing modification on just one item, we could return
            // 'False' after processing the proper one.
            return true
        }
    }

    public func removePolygons() {
        polygonDataSource.removeAll()
    }
}

extension CGFloat {
    static var random: CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension UIColor {
    static var random: UIColor {
        return UIColor(red: .random, green: .random, blue: .random, alpha: 1.0)
    }

    var hexString: String {
        guard let components = self.cgColor.components else {
            return "#000000"
        }
        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255))
    }
}
