/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
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

class CartoPOIPickingExample: TapDelegate {
    
    private let mapView: MapView
    private let searchEngine: SearchEngine
    private let currentMapScheme: MapScheme
    private let iconProvider: IconProvider

    init(_ mapView: MapView) {
        self.mapView = mapView
        iconProvider = IconProvider(self.mapView.mapContext)
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.518043, longitude: 13.405991),
                      zoom: distanceInMeters)
        
        do {
            // Allows to search online.
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
        }
        currentMapScheme = MapScheme.normalDay
        
        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: currentMapScheme, completion: onLoadScene)
    }
    
    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }
        
        startExample()
    }
    
    private func startExample() {
        showDialog(title: "Tap on Map Content",
                   message: "This app shows how to pick vehicle restrictions and embedded markers on the map, such as subway stations and ATMs.")

        enableVehicleRestrictionsOnMap()

        // Setting a tap handler to pick embedded map content.
        mapView.gestures.tapDelegate = self
    }

    private func enableVehicleRestrictionsOnMap() {
        mapView.mapScene.enableFeatures([MapFeatures.vehicleRestrictions:
                                         MapFeatureModes.vehicleRestrictionsActiveAndInactiveDifferentiated])
    }

    // Conforming to TapDelegate protocol.
    func onTap(origin: Point2D) {
        // You can also use a larger area to include multiple map icons.
        let rectangle2D = Rectangle2D(origin: origin,
                                      size: Size2D(width: 50, height: 50))
        // Creates a list of map content type from which the results will be picked.
        // The content type values can be mapContent, mapItems and customLayerData.
        var contentTypesToPickFrom = Array<MapScene.MapPickFilter.ContentType>();
        
        // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need carto POIs so adding the mapContent filter.
        contentTypesToPickFrom.append(MapScene.MapPickFilter.ContentType.mapContent);
        let filter = MapScene.MapPickFilter(filter: contentTypesToPickFrom)
        mapView.pick(filter:filter,inside: rectangle2D, completion: onMapItemsPicked)
    }

    // Completion handler to receive picked map icons.
    func onMapItemsPicked(mapPickResults: MapPickResult?) {
        guard let mapPickResults = mapPickResults else {
            print("Pick operation failed.")
            return
        }
        guard let pickedMapContent =  mapPickResults.mapContent else {
            print("Pick operation failed.")
            return
        }
        handlePickedCartoPOIs(pickedMapContent.pickedPlaces)
        handlePickedTrafficIncidents(pickedMapContent.trafficIncidents)
        handlePickedVehicleRestrictions(pickedMapContent.vehicleRestrictions)
    }

    private func handlePickedCartoPOIs(_ cartoPOIList: [PickedPlace]) {
        if cartoPOIList.count == 0 {
            // No results found at pick location.
            return
        }

        let topmostCartoPOI = cartoPOIList.first!
        let name = topmostCartoPOI.name
        let lat = topmostCartoPOI.coordinates.latitude
        let lon = topmostCartoPOI.coordinates.longitude
        showDialog(title: "Carto POI picked",
                   message: "Name: \(name). Location: \(lat), \(lon). See log for more place details.")

        // Now you can use the SearchEngine (via PickedPlace)
        // to retrieve the Place object containing more details.
        // Below we use the placeCategoryId.
        fetchCartoPOIDetails(topmostCartoPOI)
    }

    private func fetchCartoPOIDetails(_ pickedPlace: PickedPlace) {
        // Set nil for LanguageCode to get the results in their local language.
        let languageCode: LanguageCode? = nil
        searchEngine.searchByPickedPlace(pickedPlace,
                                         languageCode: languageCode,
                                         completion: onSearchCompleted)
    }

    // Completion handler to receive search results.
    func onSearchCompleted(error: SearchError?, place: Place?) {
        if let searchError = error {
            print("Place ID search: \(searchError)")
            return
        }

        // Below are just a few examples. Much more details can be retrieved, if desired.
        let title = place!.title;
        let addressText = place!.address.addressText;
        print("Title: \(title)");
        print("Address: \(addressText)");
    }

    private func handlePickedTrafficIncidents(_ trafficIndicents: [PickMapContentResult.TrafficIncidentResult]) {
        // See Traffic example app.
    }

    private func handlePickedVehicleRestrictions(_ vehicleRestrictions: [PickMapContentResult.VehicleRestrictionResult]) {
        if vehicleRestrictions.count == 0 {
            return
        }

        let topmostVehicleRestriction = vehicleRestrictions.first!

        createVehicleRestrictionIcon(vehicleRestrictionResult: topmostVehicleRestriction)
    }
    
    private func createVehicleRestrictionIcon(vehicleRestrictionResult: PickMapContentResult.VehicleRestrictionResult){
        print("Mapview validity: \(self.mapView.isValid)")
        let iconCallback: IconProviderCallback = { icon, description, error in
            if let error = error {
                self.showDialog(title: "IconProvider error ", message: "An error occurred while creating the icon: \(error)")
            } else {
                self.showDialog(title:"Vehicle restriction picked", message: " \(String(describing: description))", icon: icon)
            }
        }
        let size = Size2D(width: 20.0, height: 20.0)
        
        // Creates an image representing a vehicle restriction based on the picked content.
        // Parameters:
        // - vehicleRestrictionResult: The result of picking a vehicle restriction object from PickMapContentResult.
        // - currentMapScheme: The current map scheme of the MapView.
        // - IconProviderAssetType: Specifies icon optimization for either ui or map.
        // - size: The size of the generated image in the callback.
        // - iconProviderCallback: The callback object for receiving the generated icon.
        iconProvider.createVehicleRestrictionIcon(pickingResult: vehicleRestrictionResult, mapScheme: currentMapScheme, assetType: IconProviderAssetType.ui, sizeConstraintsInPixels: size, completion: iconCallback)
        
    }
    
    private func showDialog(title: String, message: String) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {

            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                // Handle OK button action.
                alert.dismiss(animated: true, completion: nil)
            }))

            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showDialog(title: String, message: String, icon: UIImage?) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return
        }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .alert)

        // Create a view controller for the custom alert content
        let customViewController = UIViewController()
        customViewController.view.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        if let icon = icon {
            let imageView = UIImageView(image: icon)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 50).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 50).isActive = true
            stackView.addArrangedSubview(imageView)
        }

        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        // Message
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        stackView.addArrangedSubview(messageLabel)

        customViewController.view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: customViewController.view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: customViewController.view.centerYAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: customViewController.view.widthAnchor, constant: -20)
        ])

        alertController.setValue(customViewController, forKey: "contentViewController")

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
        }

        alertController.addAction(okAction)

        rootViewController.present(alertController, animated: true, completion: nil)
    }

}
