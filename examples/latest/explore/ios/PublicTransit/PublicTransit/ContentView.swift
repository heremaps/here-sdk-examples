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
import SwiftUI

struct ContentView: View {
    
    @State private var mapView = MapView()
    @State private var publicTransitExample: PublicTransitExample?
    
    var body: some View {
         // Show the views on top of each other.
         ZStack(alignment: .top) {
             
             // The map view should fill the entire screen.
             WrappedMapView(mapView: $mapView)
                 .edgesIgnoringSafeArea(.all)
             
             HStack {
                 CustomButton(title: "Add transit route") {
                     publicTransitExample?.addTransitRoute()
                 }
                 CustomButton(title: "Clear map") {
                     publicTransitExample?.clearMap()
                 }
             }
         }
         .onAppear {
             // ContentView appeared, now we init the example.
             publicTransitExample = PublicTransitExample(mapView)
         }
     }
}

// The MapView provided by the HERE SDK conforms to a UIKit view, so it needs to be wrapped to conform
// to a SwiftUI view. The map view is created in the ContentView and bound here.
private struct WrappedMapView: UIViewRepresentable {
    @Binding var mapView: MapView
    func makeUIView(context: Context) -> MapView { return mapView }
    func updateUIView(_ mapView: MapView, context: Context) { }
}

// A reusable button to keep the layout clean.
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
