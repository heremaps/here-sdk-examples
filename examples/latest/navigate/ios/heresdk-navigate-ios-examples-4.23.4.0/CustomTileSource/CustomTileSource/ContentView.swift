/*
 * Copyright (C) 2022-2025 HERE Europe B.V.
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
import SwiftUI

struct ContentView: View {
    @State private var mapView = MapView()
    @State private var customPointTileSourceExample: CustomPointTileSourceExample?
    @State private var customRasterTileSourceExample: CustomRasterTileSourceExample?
    @State private var customPolygonTileSourceExample: CustomPolygonTileSourceExample?
    @State private var customLineTileSourceExample: CustomLineTileSourceExample?
    // Default selection
    @State private var isPointTileOn = true
    @State private var isLineTileOn = false
    @State private var isRasterTileOn = false
    @State private var isPolygonTileOn = false
    
    var body: some View {
        ZStack(alignment: .top) {
            WrappedMapView(mapView: $mapView)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Toggle("Point Tile", isOn: $isPointTileOn)
                        .onChange(of: isPointTileOn) { isOn in
                            isOn ? enableSelectedTileSource(selectedTileSource: "customPointTileSource") : disableSelectedTileSource(selectedTileSource: "customPointTileSource")
                        }
                        .padding()
                    Toggle("Raster Tile", isOn: $isRasterTileOn)
                        .onChange(of: isRasterTileOn) { isOn in
                            isOn ? enableSelectedTileSource(selectedTileSource: "customRasterTileSource") : disableSelectedTileSource(selectedTileSource: "customRasterTileSource")
                        }
                        .padding()
                }
                HStack {
                    Toggle("Line Tile", isOn: $isLineTileOn)
                        .onChange(of: isLineTileOn) { isOn in
                            isOn ? enableSelectedTileSource(selectedTileSource: "customLineTileSource") : disableSelectedTileSource(selectedTileSource: "customLineTileSource")
                        }
                        .padding()
                    Toggle("Polygon Tile", isOn: $isPolygonTileOn)
                        .onChange(of: isPolygonTileOn) { isOn in
                            isOn ? enableSelectedTileSource(selectedTileSource: "customPolygonTileSource") : disableSelectedTileSource(selectedTileSource: "customPolygonTileSource")
                        }
                        .padding()
                }
            }
            .background(Color.white)
        }
        .onAppear {
            customPointTileSourceExample = CustomTileSource.CustomPointTileSourceExample(mapView)
            customRasterTileSourceExample = CustomTileSource.CustomRasterTileSourceExample(mapView)
            customPolygonTileSourceExample = CustomTileSource.CustomPolygonTileSourceExample(mapView)
            customLineTileSourceExample = CustomTileSource.CustomLineTileSourceExample(mapView)
        }
    }
    
    private func enableSelectedTileSource(selectedTileSource: String) {
        switch selectedTileSource {
        case "customPointTileSource":
            customPointTileSourceExample?.enableLayer()
        case "customRasterTileSource":
            customRasterTileSourceExample?.enableLayer()
        case "customLineTileSource":
            customLineTileSourceExample?.enableLayer()
        case "customPolygonTileSource":
            customPolygonTileSourceExample?.enableLayer()
        default:
            break
        }
    }
    
    private func disableSelectedTileSource(selectedTileSource: String) {
        switch selectedTileSource {
        case "customPointTileSource":
            customPointTileSourceExample?.disableLayer()
        case "customRasterTileSource":
            customRasterTileSourceExample?.disableLayer()
        case "customLineTileSource":
            customLineTileSourceExample?.disableLayer()
        case "customPolygonTileSource":
            customPolygonTileSourceExample?.disableLayer()
        default:
            break
        }
    }
}

private struct WrappedMapView: UIViewRepresentable {
    @Binding var mapView: MapView
    func makeUIView(context: Context) -> MapView { return mapView }
    func updateUIView(_ mapView: MapView, context: Context) { }
}

struct CustomButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
                .background(Color(red: 0, green: 182/255, blue: 178/255))
                .foregroundColor(.white)
                .cornerRadius(5)
        }
    }
}
