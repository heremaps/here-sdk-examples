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
    
    // Initialize the models for the SpeedView using default values.
    @StateObject private var truckSpeedLimitModel = SpeedModel()
    @StateObject private var carSpeedLimitModel = SpeedModel()
    @StateObject private var drivingSpeedModel = SpeedModel()
    
    // Initialize the model for the TruckRestrictionView using default values.
    @StateObject private var truckRestrictionModel = TruckRestrictionModel()
    
    @State private var mapView = MapView()
    @State private var truckGuidanceExample: TruckGuidanceExample?
        
    var body: some View {
         // Show the views on top of each other.
         ZStack(alignment: .top) {
             
             // The map view should fill the entire screen.
             WrappedMapView(mapView: $mapView)
                 .edgesIgnoringSafeArea(.all)
             
             VStack {
                 HStack {
                     CustomButton(title: "Show") {
                         truckGuidanceExample?.onShowRouteClicked()
                     }
                     CustomButton(title: "Start/Stop") {
                         truckGuidanceExample?.onStartStopClicked()
                     }
                     CustomButton(title: "Clear") {
                         truckGuidanceExample?.onClearClicked()
                     }
                     CustomButton(title: "Tracking") {
                         truckGuidanceExample?.onTrackingOnOffClicked()
                     }
                 }
                 HStack {
                     CustomButton(title: "Toggle Speed") {
                         truckGuidanceExample?.onToggleSpeedClicked()
                     }
                 }

                 // Position all UI components in the bottom-left screen area.
                 VStack {
                     Spacer()
                     
                     HStack {
                         TruckRestrictionView(model: truckRestrictionModel)
                     }
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .padding()
                     
                     HStack {
                         SpeedView(model: truckSpeedLimitModel)
                         SpeedView(model: carSpeedLimitModel)
                         SpeedView(model: drivingSpeedModel)
                     }
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .padding(.leading)
                 }
                 .frame(maxHeight: .infinity, alignment: .bottom)
             }
         }
         .onAppear {
             // ContentView appeared, now we init the example.
             truckGuidanceExample = TruckGuidanceExample(mapView,
                                                         truckSpeedLimitModel: truckSpeedLimitModel,
                                                         carSpeedLimitModel: carSpeedLimitModel,
                                                         drivingSpeedModel: drivingSpeedModel,
                                                         truckRestrictionModel: truckRestrictionModel)
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
