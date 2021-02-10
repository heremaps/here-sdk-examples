/*
 * Copyright (C) 2019-2021 HERE Europe B.V.
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
                     LongPressDelegate {

    private var viewController: UIViewController
    private var mapView: MapView
    private var mapMarkers = [MapMarker]()
    private var searchEngine: SearchEngine

    init(viewController: UIViewController, mapView: MapView) {
        self.viewController = viewController
        self.mapView = mapView
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      distanceInMeters: 1000 * 10)

        do {
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
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

        let textQuery = TextQuery(queryString, in: getMapViewGeoBox())
        let searchOptions = SearchOptions(languageCode: LanguageCode.enUs,
                                          maxItems: 30)
        _ = searchEngine.search(textQuery: textQuery,
                                options: searchOptions,
                                completion: onSearchCompleted)
    }

    // Completion handler to receive search results.
    func onSearchCompleted(error: SearchError?, items: [Place]?) {
        if let searchError = error {
            showDialog(title: "Search", message: "Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        showDialog(title: "Search in viewport for: 'Pizza'.",
                   message: "Found  \(items!.count) results.")

        // Add a new marker for each search result on map.
        for searchResult in items! {
            let metadata = Metadata()
            metadata.setCustomValue(key: "key_search_result", value: SearchResultMetadata(searchResult))
            // Note that geoCoordinates are always set, but can be nil for suggestions only.
            addPoiMapMarker(geoCoordinates: searchResult.geoCoordinates!, metadata: metadata)
        }
    }

    private class SearchResultMetadata : CustomMetadataValue {

        var searchResult: Place

        init(_ searchResult: Place) {
            self.searchResult = searchResult
        }

        func getTag() -> String {
            return "SearchResult Metadata"
        }
    }

    private func autoSuggestExample() {
        let centerGeoCoordinates = getMapViewCenter()
        let autosuggestOptions = SearchOptions(languageCode: LanguageCode.enUs,
                                               maxItems: 5)

        // Simulate a user typing a search term.
        _ = searchEngine.suggest(textQuery: TextQuery("p", near: centerGeoCoordinates),
                                 options: autosuggestOptions,
                                 completion: onSearchCompleted)

        _ = searchEngine.suggest(textQuery: TextQuery("pi", near: centerGeoCoordinates),
                                 options: autosuggestOptions,
                                 completion: onSearchCompleted)

        _ = searchEngine.suggest(textQuery: TextQuery("piz", near: centerGeoCoordinates),
                                 options: autosuggestOptions,
                                 completion: onSearchCompleted)
    }

    // Completion handler to receive auto suggestion results.
    func onSearchCompleted(error: SearchError?, items: [Suggestion]?) {
        if let searchError = error {
            print("Autosuggest Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        print("Autosuggest: Found \(items!.count) result(s).")

        for autosuggestResult in items! {
            var addressText = "Not a place."
            if let place = autosuggestResult.place {
                addressText = place.address.addressText
            }
            print("Autosuggest result: \(autosuggestResult.title), addressText: \(addressText)")
        }
    }

    public func geocodeAnAddress() {
        // Set map near to expected location.
        let geoCoordinates = GeoCoordinates(latitude: 52.537931, longitude: 13.384914)
        mapView.camera.lookAt(point: geoCoordinates, distanceInMeters: 1000 * 5)

        let streetName = "Invalidenstraße 116, Berlin"
        geocodeAddressAtLocation(queryString: streetName, geoCoordinates: geoCoordinates)
    }

    private func geocodeAddressAtLocation(queryString: String, geoCoordinates: GeoCoordinates) {
        clearMap()

        let query = AddressQuery(queryString, near: geoCoordinates)
        let geocodingOptions = SearchOptions(languageCode: LanguageCode.deDe,
                                             maxItems: 25)
        _ = searchEngine.search(addressQuery: query,
                                options: geocodingOptions,
                                completion: onGeocodingCompleted)
    }

    // Completion handler to receive geocoding results.
    func onGeocodingCompleted(error: SearchError?, items: [Place]?) {
        if let searchError = error {
            showDialog(title: "Geocoding", message: "Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        for geocodingResult in items! {
            // Note that geoCoordinates are always set, but can be nil for suggestions only.
            let geoCoordinates = geocodingResult.geoCoordinates!
            let address = geocodingResult.address
            let locationDetails = address.addressText
                + ". Coordinates: \(geoCoordinates.latitude)"
                + ", \(geoCoordinates.longitude)"

            showDialog(title: "Geocoding - Locations in viewport for 'Invalidenstraße 116, Berlin':",
                       message: "Found: \(items!.count) result(s): \(locationDetails)")

            self.addPoiMapMarker(geoCoordinates: geoCoordinates)
        }
    }

    // Conforming to TapDelegate protocol.
    func onTap(origin: Point2D) {
        mapView.pickMapItems(at: origin, radius: 2, completion: onMapItemsPicked)
    }

    // Completion handler to receive picked map items.
    func onMapItemsPicked(pickedMapItems: PickMapItemsResult?) {
        guard let topmostMapMarker = pickedMapItems?.markers.first else {
            return
        }

        if let searchResultMetadata =
            topmostMapMarker.metadata?.getCustomValue(key: "key_search_result") as? SearchResultMetadata {

            let title = searchResultMetadata.searchResult.title
            let vicinity = searchResultMetadata.searchResult.address.addressText
            showDialog(title: "Picked Search Result",
                       message: "Title: \(title), Vicinity: \(vicinity)")
            return
        }

        showDialog(title: "Map Marker picked at: ",
                   message: "\(topmostMapMarker.coordinates.latitude), \(topmostMapMarker.coordinates.longitude)")
    }

    // Conforming to LongPressDelegate protocol.
    func onLongPress(state: GestureState, origin: Point2D) {
        if (state == .begin) {
            let geoCoordinates = mapView.viewToGeoCoordinates(viewCoordinates: origin)
            addPoiMapMarker(geoCoordinates: geoCoordinates!)
            getAddressForCoordinates(geoCoordinates: geoCoordinates!)
        }
    }

    private func getAddressForCoordinates(geoCoordinates: GeoCoordinates) {
        // By default results are localized in EN_US.
        let reverseGeocodingOptions = SearchOptions(languageCode: LanguageCode.enGb,
                                                    maxItems: 1)
        _ = searchEngine.search(coordinates: geoCoordinates,
                                options: reverseGeocodingOptions,
                                completion: onReverseGeocodingCompleted)
    }

    // Completion handler to receive reverse geocoding results.
    func onReverseGeocodingCompleted(error: SearchError?, items: [Place]?) {
        if let searchError = error {
            showDialog(title: "ReverseGeocodingError", message: "Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the place list will not be empty.
        let addressText = items!.first!.address.addressText
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
        guard
            let image = UIImage(named: "poi"),
            let imageData = image.pngData() else {
                fatalError("Error: Image not found.")
        }
        let mapMarker = MapMarker(at: geoCoordinates,
                                  image: MapImage(pixelData: imageData,
                                                  imageFormat: ImageFormat.png),
                                  anchor: Anchor2D(horizontal: 0.5, vertical: 1))
        return mapMarker
    }

    private func getMapViewCenter() -> GeoCoordinates {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)
        let centerPoint2D = Point2D(x: mapViewWidthInPixels / 2,
                                    y: mapViewHeightInPixels / 2)

        return mapView.viewToGeoCoordinates(viewCoordinates: centerPoint2D)!
    }

    private func getMapViewGeoBox() -> GeoBox {
        let scaleFactor = UIScreen.main.scale
        let mapViewWidthInPixels = Double(mapView.bounds.width * scaleFactor)
        let mapViewHeightInPixels = Double(mapView.bounds.height * scaleFactor)
        let bottomLeftPoint2D = Point2D(x: 0, y: mapViewHeightInPixels)
        let topRightPoint2D = Point2D(x: mapViewWidthInPixels, y: 0)

        let southWestCorner = mapView.viewToGeoCoordinates(viewCoordinates: bottomLeftPoint2D)!
        let northEastCorner = mapView.viewToGeoCoordinates(viewCoordinates: topRightPoint2D)!

        // Note: This algorithm assumes an unrotated map view.
        return GeoBox(southWestCorner: southWestCorner, northEastCorner: northEastCorner)
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
    }
}
