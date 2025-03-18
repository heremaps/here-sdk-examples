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
    @State private var customLineTileSourceExample: CustomLineTileSourceExample?
    @State private var selectedTileSource: String = "customPointTileSource" // Default selection
    
    var body: some View {
        ZStack(alignment: .top) {
            WrappedMapView(mapView: $mapView)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    RadioButton(title: "Point Tile", isSelected: selectedTileSource == "customPointTileSource") {
                        selectedTileSource = "customPointTileSource"
                    }
                    RadioButton(title: "Raster Tile", isSelected: selectedTileSource == "customRasterTileSource") {
                        selectedTileSource = "customRasterTileSource"
                    }
                    RadioButton(title: "Line Tile", isSelected: selectedTileSource == "customLineTileSource") {
                        selectedTileSource = "customLineTileSource"
                    }
                }
                .padding()
                
                HStack {
                    CustomButton(title: "Enable") {
                        enableSelectedTileSource()
                    }
                    CustomButton(title: "Disable") {
                        disableSelectedTileSource()
                    }
                }
            }
        }
        .onAppear {
            customPointTileSourceExample = CustomTileSource.CustomPointTileSourceExample(mapView)
            customRasterTileSourceExample = CustomTileSource.CustomRasterTileSourceExample(mapView)
            customLineTileSourceExample = CustomTileSource.CustomLineTileSourceExample(mapView)
        }
    }
    
    private func enableSelectedTileSource() {
        switch selectedTileSource {
        case "customPointTileSource":
            customPointTileSourceExample?.onEnableButtonClicked()
        case "customRasterTileSource":
            customRasterTileSourceExample?.onEnableButtonClicked()
        case "customLineTileSource":
            customLineTileSourceExample?.onEnableButtonClicked()
        default:
            break
        }
    }
    
    private func disableSelectedTileSource() {
        switch selectedTileSource {
        case "customPointTileSource":
            customPointTileSourceExample?.onDisableButtonClicked()
        case "customRasterTileSource":
            customRasterTileSourceExample?.onDisableButtonClicked()
        case "customLineTileSource":
            customLineTileSourceExample?.onDisableButtonClicked()
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

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(.blue)
                Text(title)
                    .foregroundColor(.black)
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
