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

    @State private var offlineMapsExample: OfflineMapsExample?
    @State private var messageText = ""
    @StateObject private var mapViewObservable = MapViewObservable()
    @State private var isMapViewVisible = true // Toggle visibility

    
    var body: some View {
         // Show the views on top of each other.
         ZStack(alignment: .top) {
             
             // Conditionally render the map view
             if isMapViewVisible {
                 WrappedMapView(mapViewObservable: mapViewObservable)
                     .edgesIgnoringSafeArea(.all)
             }
             
             VStack {
                 HStack {
                     CustomButton(title: "Regions") {
                         offlineMapsExample!.onDownloadListClicked()
                     }
                     CustomButton(title: "Download") {
                         offlineMapsExample!.onDownloadMapClicked()
                     }
                     CustomButton(title: "Clear Cache"){
                         offlineMapsExample!.clearCache()
                     }
                 }
                 HStack{
                     CustomToggleButton(onLabel: "offlineSearch layer: OFF", offLabel: "offlineSearch layer: ON") {
                         offlineMapsExample!.toggleConfiguration()
                         
                         // In SwiftUI, UIViewRepresentable views may not always be recreated when their state changes,
                         // especially when SwiftUI performs optimizations like view recycling.
                         // To ensure that a UIViewRepresentable is fully recreated (i.e., makeUIView is called again),
                         // we can toggle the visibility of the view, effectively removing it from the view hierarchy
                         // and then re-adding it.
                         isMapViewVisible = false
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                             isMapViewVisible = true
                         }

                     }
                     CustomButton(title: "Area") {
                         offlineMapsExample!.onDownloadAreaClicked()
                     }
                     CustomButton(title: "Cancel") {
                         offlineMapsExample!.onCancelMapDownloadClicked()
                     }
                 }
                 HStack {
                     CustomButton(title: "Test offline Search") {
                         offlineMapsExample!.onSearchPlaceClicked()
                     }
                     CustomToggleButton(onLabel: "Offline Mode: On", offLabel: "Offline Mode: Off") {
                         offlineMapsExample!.toggleOfflineMode()
                     }
                     
                 }
                 HStack(){
                     MessageView(message: messageText)                 }
             }
             .font(.subheadline)
             
         }
         .onAppear {
             // ContentView appeared, now we init the example.
             offlineMapsExample = OfflineMapsExample(mapViewObservable: mapViewObservable, showMessageClosure: showMessage)
         }
     }
    
    // Displays information provided from the OfflineMapsExample about the download status and 
    // other related information.
    private func showMessage(_ message: String) {
        messageText = message
    }
}


// The MapView provided by the HERE SDK conforms to a UIKit view, so it needs to be wrapped to conform
// to a SwiftUI view. The map view is created in the ContentView and bound here.
private struct WrappedMapView: UIViewRepresentable{
    @ObservedObject var mapViewObservable: MapViewObservable

     func makeUIView(context: Context) -> MapView {
         if mapViewObservable.mapView == nil{
             mapViewObservable.configureMapView()
         }
         
         return mapViewObservable.mapView!
     }

     func updateUIView(_ uiView: MapView, context: Context) {
         // Updates will automatically apply due to observable properties
     }
}

// A reusable button to keep the layout clean.
struct CustomButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
                .background(Color.buttonBackground)
                .foregroundColor(.white)
                .cornerRadius(5)
        }
    }
}

// A reusable toggle button to keep the layout clean.
struct CustomToggleButton: View {
    @State private var isOn: Bool = false
    var onLabel: String
    var offLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            isOn.toggle()
            action()
        }) {
            Text(isOn ? onLabel : offLabel)
                .padding()
                .background(Color(red: 0, green: 182/255, blue: 178/255))
                .foregroundColor(.white)
                .cornerRadius(5)
        }
    }
}


// A reusable text view to keep the layout clean.
struct MessageView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: UIScreen.main.bounds.width * 0.9)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.3)
                .background(Color.messageBackground)
                .cornerRadius(8)
                .overlay(
                    ScrollView {
                        Text(message)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .padding()
                            .multilineTextAlignment(.center)
                    }
                )
                .padding()
                .position(x: UIScreen.main.bounds.width * 0.5, y: UIScreen.main.bounds.height * 0.5)
                .transition(.opacity)
        }
    }
}

extension Color {
    static let buttonBackground = Color(red: 0, green: 182 / 255, blue: 178 / 255)
    static let messageBackground = Color(red: 0, green: 144 / 255, blue: 138 / 255)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
