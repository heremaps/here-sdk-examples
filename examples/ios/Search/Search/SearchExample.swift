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

class SearchExample: TapDelegate,
                     LongPressDelegate,
                     GeocodingCallback,
                     ReverseGeocodingCallback,
                     PickMapItemsCallback {

    private var viewController: UIViewController!
    private var mapView: MapView!
    private var mapMarkers = [MapMarker]()
    private var searchEngine: SearchEngine!
    private var geocodingEngine: GeocodingEngine!
    private var reverseGeocodingEngine: ReverseGeocodingEngine!

    func onMapSceneLoaded(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
        camera.setZoomLevel(14)

        mapView.gestures.tapDelegate = self
        mapView.gestures.longPressDelegate = self

        do {
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
        }

        do {
            try geocodingEngine = GeocodingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize GeocodingEngine. Cause: \(engineInstantiationError)")
        }

        do {
            try reverseGeocodingEngine = ReverseGeocodingEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize ReverseGeocodingEngine. Cause: \(engineInstantiationError)")
        }

        showDialog(title: "Note", message: "Long press on map to get the address for that position using reverse geocoding.")
    }

    func onSearchButtonClicked() {
        searchExample()
    }

    func onGeoCodeButtonClicked() {
        geocodeAnAddress()
    }

    public func searchExample() {
        let searchTerm = "Pizza"
        searchAtMapCenter(queryString: searchTerm)
    }

    private func searchAtMapCenter(queryString: String) {
        clearMap()

        let searchOptions = SearchOptions(
            languageCode: LanguageCode.enUs,
            maxItems: 30)

        searchEngine.search(at: mapView.camera.getTarget(),
                            query: queryString,
                            options: searchOptions) { (searchError, searchItems) in

                                if let error = searchError {
                                    self.showDialog(title: "Search", message: "Error: \(error)")
                                    return
                                }

                                if searchItems!.isEmpty {
                                    self.showDialog(title: "Search", message: "No results found")
                                    return
                                }

                                self.showDialog(title: "Search around current map center for: 'Pizza'.",
                                                message: "Found  \(searchItems!.count) results.")

                                // Add new marker for each search result on map.
                                for searchItem in searchItems! {
                                    let metadata = Metadata()
                                    metadata.setCustomValue(key: "key_search_item", value: SearchItemMetadata(searchItem))
                                    self.addPoiMapMarker(geoCoordinates: searchItem.coordinates, metadata: metadata)
                                }
        }
    }

    private class SearchItemMetadata : CustomMetadataValue {

        var searchItem: SearchItem

        init(_ searchItem: SearchItem) {
            self.searchItem = searchItem
        }

        func getTag() -> String {
            return "SearchItem Metadata"
        }
    }

    public func geocodeAnAddress() {
        // Set map to expected location.
        mapView.camera.setTarget(GeoCoordinates(latitude: 52.530932, longitude: 13.384915))

        let streetName = "Invalidenstraße 116"
        geocodeAddressInViewport(queryString: streetName)
    }

    private func geocodeAddressInViewport(queryString: String) {
        clearMap()

        let geocodingOptions = GeocodingOptions(
            languageCode: LanguageCode.deDe,
            maxItems: 25)

        geocodingEngine.searchLocations(in: mapView.camera.boundingRect,
                                        addressQuery: queryString,
                                        options: geocodingOptions,
                                        callback: self)
    }

    // Conforming to GeocodingCallback protocol.
    func onSearchCompleted(geocodingError: GeocodingError?, items: [GeocodingResult]?) {
        if let error = geocodingError {
            showDialog(title: "Geocoding", message: "Error: \(error)")
            return
        }

        if items!.isEmpty {
            showDialog(title: "Geocoding", message: "No geocoding results found.")
            return
        }

        for geocodingResult in items! {
            if let geoCoordinates = geocodingResult.geoCoordinates, let address = geocodingResult.address {
                let locationDetails = address.addressText
                    + ". Coordinates: \(geoCoordinates.latitude)"
                    + ", \(geoCoordinates.longitude)"

                showDialog(title: "Geocoding - Locations for 'Invalidenstraße 116':",
                           message: "Found: \(items!.count) result(s): \(locationDetails)")

                self.addPoiMapMarker(geoCoordinates: geoCoordinates)
            }
        }
    }

    // Conforming to TapDelegate protocol.
    func onTap(origin: Point2D) {
        mapView.pickMapItems(at: origin, radius: 2, callback: self)
    }

    // Conforming to PickMapItemsCallback protocol.
    func onMapItemsPicked(pickedMapItems: PickMapItemsResult?) {
        guard let mapItems = pickedMapItems else {
            return
        }

        guard let topmostMapMarker = mapItems.topmostMarker else {
            return
        }

        if let metadata = topmostMapMarker.metadata {
            if let customMetadataValue = metadata.getCustomValue(key: "key_search_item") {
                if let searchItemMetadata = customMetadataValue as? SearchItemMetadata {
                    let title = searchItemMetadata.searchItem.title
                    let vicinity = searchItemMetadata.searchItem.vicinity ?? "nil"
                    showDialog(title: "Picked Search Result",
                               message: title + ", " + vicinity)
                    return
                }
            }
        }

        showDialog(title: "Map Marker picked at: ",
                   message: "\(topmostMapMarker.coordinates.latitude), \(topmostMapMarker.coordinates.longitude)")
    }

    // Conforming to LongPressDelegate protocol.
    func onLongPress(state: GestureState, origin: Point2D) {
        if (state == .begin) {
            let geoCoordinates = mapView.camera.viewToGeoCoordinates(viewCoordinates: origin)
            addPoiMapMarker(geoCoordinates: geoCoordinates)
            getAddressForCoordinates(geoCoordinates: geoCoordinates)
        }
    }

    private func getAddressForCoordinates(geoCoordinates: GeoCoordinates) {
        // By default results are localized in EN_US.
        let reverseGeocodingOptions = ReverseGeocodingOptions(languageCode: LanguageCode.enGb)

        reverseGeocodingEngine.searchAddress(coordinates: geoCoordinates,
                                             options: reverseGeocodingOptions,
                                             callback: self)
    }

    // Conforming to ReverseGeocodingCallback protocol.
    func onSearchCompleted(reverseGeocodingError: ReverseGeocodingError?,
                           address: Address?) {
        if let error = reverseGeocodingError {
            showDialog(title: "ReverseGeocodingError", message: "Error: \(error)")
            return
        }

        let addressText = address!.addressText
        showDialog(title: "Reverse geocoded address:", message: addressText)
    }

    private func addPoiMapMarker(geoCoordinates: GeoCoordinates) {
        let mapMarker = createPoiMapMarker(geoCoordinates: geoCoordinates)
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func addPoiMapMarker(geoCoordinates: GeoCoordinates, metadata: Metadata) {
        let mapMarker = createPoiMapMarker(geoCoordinates: geoCoordinates)
        mapMarker.metadata = metadata
        mapView.mapScene.addMapMarker(mapMarker)
        mapMarkers.append(mapMarker)
    }

    private func createPoiMapMarker(geoCoordinates: GeoCoordinates) -> MapMarker {
        let mapMarker = MapMarker(at: geoCoordinates)
        let image = UIImage(named: "poi")
        let mapImage = MapImage(image!)
        let mapMarkerImageStyle = MapMarkerImageStyle()
        mapMarkerImageStyle.setAnchorPoint(Anchor2D(horizontal: 0.5, vertical: 1))
        mapMarker.addImage(mapImage!, style: mapMarkerImageStyle)
        return mapMarker
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }

    private func clearMap() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }

        mapMarkers.removeAll()
    }}
