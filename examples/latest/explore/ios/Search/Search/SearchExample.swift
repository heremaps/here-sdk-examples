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

class SearchExample: TapDelegate,
                     LongPressDelegate {

    private let mapView: MapView
    private let searchEngine: SearchEngine
    private var mapMarkers = [MapMarker]()

    init(_ mapView: MapView) {
        self.mapView = mapView
        
        // Configure the map.
        let camera = mapView.camera
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 10)
        camera.lookAt(point: GeoCoordinates(latitude: 52.520798, longitude: 13.409408),
                      zoom: distanceInMeters)

        do {
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize SearchEngine. Cause: \(engineInstantiationError)")
        }

        mapView.gestures.tapDelegate = self
        mapView.gestures.longPressDelegate = self

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)
        
        enableWebImages()
        
        showDialog(title: "Note", message: "Long press on map to get the address for that position using reverse geocoding.")
    }

    // Completion handler for loadScene().
    private func onLoadScene(mapError: MapError?) {
        if let mapError = mapError {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
        }
    }
    
    func enableWebImages() {
        // Enable search results with web images.
        // Note: Requires enabled credentials to receive rich content from TripAdvisor.
        // Talk to your HERE representative to get access.
        // If the license is missing, the images list will be empty.
        searchEngine.setCustomOption(name: "discover.show", value: "tripadvisor");
    }
    
    // Call enableWebImages() to receive web images for places.
    func handleWebImages(searchResult: Place) {
        let webImages = searchResult.details.images
        for webImage in webImages {
            print("WebImage found for place: \(searchResult.title.trimmingCharacters(in: .whitespaces)). Link: \(webImage.source.href)")
        }
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

        let queryArea = TextQuery.Area(inBox: getMapViewGeoBox())
        let textQuery = TextQuery(queryString, area: queryArea)
        let searchOptions = SearchOptions(languageCode: LanguageCode.enUs,
                                          maxItems: 30)
        _ = searchEngine.searchByText(textQuery,
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
            handleWebImages(searchResult: searchResult)
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
        
        let queryArea = TextQuery.Area(areaCenter: centerGeoCoordinates)
        
        // Simulate a user typing a search term.
        _ = searchEngine.suggestByText(TextQuery("p", area: queryArea),
                                 options: autosuggestOptions,
                                 completion: onSearchCompleted)

        _ = searchEngine.suggestByText(TextQuery("pi", area: queryArea),
                                 options: autosuggestOptions,
                                 completion: onSearchCompleted)

        _ = searchEngine.suggestByText(TextQuery("piz", area: queryArea),
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
        let geoCoordinates = GeoCoordinates(latitude: 52.53086, longitude: 13.38469)
        let distanceInMeters = MapMeasure(kind: .distanceInMeters, value: 1000 * 5)
        mapView.camera.lookAt(point: geoCoordinates, zoom: distanceInMeters)

        let streetName = "Invalidenstraße 116, Berlin"
        geocodeAddressAtLocation(queryString: streetName, geoCoordinates: geoCoordinates)
    }

    /**
     * Performs a geocoding search for the given address string near a specific location.
     *
     * @param queryString     The address or place name to search for.
     * @param geoCoordinates  The reference location used to narrow down search results
     *
     * This method clears the map, builds an AddressQuery with the provided parameters,
     * configures search options (language and max results), and executes the geocoding
     * request via the SearchEngine with a callback to handle results.
     */
    private func geocodeAddressAtLocation(queryString: String, geoCoordinates: GeoCoordinates) {
        clearMap()

        // The geoCoordinates act as a reference location to prioritize the search results.
        // This helps the SearchEngine return addresses that are more relevant and closer to the user’s
        // current location instead of global or less relevant matches.
        let query = AddressQuery(queryString, near: geoCoordinates)
        let geocodingOptions = SearchOptions(languageCode: LanguageCode.deDe,
                                             maxItems: 25)
        _ = searchEngine.searchByAddress(query,
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
        // You can also use a larger area to include multiple map icons.
        let rectangle2D = Rectangle2D(origin: origin,
                                      size: Size2D(width: 50, height: 50))
        // Creates a list of map content type from which the results will be picked.
        // The content type values can be mapContent, mapItems and customLayerData.
        var contentTypesToPickFrom = Array<MapScene.MapPickFilter.ContentType>();
        
        // mapContent is used when picking embedded carto POIs, traffic incidents, vehicle restriction etc.
        // mapItems is used when picking map items such as MapMarker, MapPolyline, MapPolygon etc.
        // Currently we need map markers so adding the mapItems filter.
        contentTypesToPickFrom.append(MapScene.MapPickFilter.ContentType.mapItems);
        var filter = MapScene.MapPickFilter(filter: contentTypesToPickFrom);
        mapView.pick(filter:filter,inside: rectangle2D, completion: onMapItemsPicked)
    }
    
    // Completion handler to receive picked map items.
    func onMapItemsPicked(mapPickResults: MapPickResult?) {
        guard let mapPickResults = mapPickResults else {
            print("Pick operation failed.")
            return
        }
        guard let pickedMapItems =  mapPickResults.mapItems else {
            print("Pick operation failed.")
            return
        }
        guard let topmostMapMarker = pickedMapItems.markers.first else {
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
    func onLongPress(state: heresdk.GestureState, origin: Point2D) {
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
        _ = searchEngine.searchByCoordinates(geoCoordinates,
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
        return mapView.camera.state.targetCoordinates
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
    
    private func clearMap() {
        for mapMarker in mapMarkers {
            mapView.mapScene.removeMapMarker(mapMarker)
        }

        mapMarkers.removeAll()
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
}
