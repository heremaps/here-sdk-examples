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
                     SearchCallback,
                     AutosuggestCallback,
                     GeocodingCallback,
                     ReverseGeocodingCallback,
                     PickMapItemsCallback {

    private var viewController: UIViewController
    private var mapView: MapViewLite
    private var mapMarkers = [MapMarker]()
    private var searchEngine: SearchEngine
    private var autosuggestEngine: AutosuggestEngine
    private var geocodingEngine: GeocodingEngine
    private var reverseGeocodingEngine: ReverseGeocodingEngine

    init(viewController: UIViewController, mapView: MapViewLite) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.setTarget(GeoCoordinates(latitude: 52.530932, longitude: 13.384915))
        camera.setZoomLevel(14)

        do {
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
        }

        do {
            try autosuggestEngine = AutosuggestEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize AutosuggestEngine. Cause: \(engineInstantiationError)")
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

        mapView.gestures.tapDelegate = self
        mapView.gestures.longPressDelegate = self

        showDialog(title: "Note", message: "Long press on map to get the address for that position using reverse geocoding.")
    }

    func onSearchButtonClicked() {
        // Search for "Pizza" and show the results on the map.
        searchExample()

        // Search for auto suggestions and log the results to the console.
        autoSuggestExample()
    }

    func onGeoCodeButtonClicked() {
        // Search for the location that belongs to an address and show it on the map.
        geocodeAnAddress()
    }

    private func searchExample() {
        let searchTerm = "Pizza"
        searchInViewport(queryString: searchTerm)
    }

    private func searchInViewport(queryString: String) {
        clearMap()

        let searchOptions = SearchOptions(
            languageCode: LanguageCode.enUs,
            textFormat: TextFormat.plain,
            maxItems: 30)

        searchEngine.search(in: mapView.camera.boundingRect,
                            query: queryString,
                            options: searchOptions,
                            callback: self)
    }

    // Conforming to SearchCallback protocol.
    func onSearchCompleted(error: SearchError?, items: [SearchItem]?) {
        if let searchError = error {
            showDialog(title: "Search", message: "Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        if items!.isEmpty {
            showDialog(title: "Search", message: "No results found")
            return
        }

        showDialog(title: "Search in viewport for: 'Pizza'.",
                   message: "Found  \(items!.count) results.")

        // Add a new marker for each search result on map.
        for searchItem in items! {
            let metadata = Metadata()
            metadata.setCustomValue(key: "key_search_item", value: SearchItemMetadata(searchItem))
            addPoiMapMarker(geoCoordinates: searchItem.coordinates, metadata: metadata)
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

    private func autoSuggestExample() {
        let centerGeoCoordinates = mapView.camera.getTarget()
        let autosuggestOptions = AutosuggestOptions(
            languageCode: LanguageCode.enUs,
            textFormat: TextFormat.plain,
            maxItems: 5,
            requestedTypes: [AutosuggestResultType.place])

        // Simulate a user typing a search term.
        _ = autosuggestEngine.suggest(at: centerGeoCoordinates,
                                  query: "p",
                                  options: autosuggestOptions,
                                  callback: self);

        _ = autosuggestEngine.suggest(at: centerGeoCoordinates,
                                  query: "pi",
                                  options: autosuggestOptions,
                                  callback: self);

        _ = autosuggestEngine.suggest(at: centerGeoCoordinates,
                                  query: "piz",
                                  options: autosuggestOptions,
                                  callback: self);
    }

    // Conforming to AutosuggestCallback protocol.
    func onSearchCompleted(error: SearchError?, items: [AutosuggestResult]?) {
        if let searchError = error {
            print("Autosuggest Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        if items!.isEmpty {
            print("Autosuggest: No results found")
            return
        }

        print("Autosuggest:Found  \(items!.count) result(s).")

        for autosuggestResult in items! {
            print("Autosuggest result: \(autosuggestResult.title), Highlighted: \(autosuggestResult.highlightedTitle)")
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
    func onSearchCompleted(error: SearchError?, items: [GeocodingResult]?) {
        if let searchError = error {
            showDialog(title: "Geocoding", message: "Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        if items!.isEmpty {
            showDialog(title: "Geocoding", message: "No geocoding results found.")
            return
        }

        for geocodingResult in items! {
            let geoCoordinates = geocodingResult.geoCoordinates
            if let address = geocodingResult.address {
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
        guard let topmostMapMarker = pickedMapItems?.topmostMarker else {
            return
        }

        if let searchItemMetadata =
            topmostMapMarker.metadata?.getCustomValue(key: "key_search_item") as? SearchItemMetadata {

            let title = searchItemMetadata.searchItem.title
            let vicinity = searchItemMetadata.searchItem.vicinity ?? "nil"
            let category = searchItemMetadata.searchItem.category
            showDialog(title: "Picked Search Result",
                       message: "\(title), \(vicinity). Category: \(category.localizedName)")
            return
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
    func onSearchCompleted(error: SearchError?,
                           address: Address?) {
        if let searchError = error {
            showDialog(title: "ReverseGeocodingError", message: "Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the address will not be nil.
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
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        viewController.present(alertController, animated: true, completion: nil)
    }

    private func clearMap() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }

        mapMarkers.removeAll()
    }}
