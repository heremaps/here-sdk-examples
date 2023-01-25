/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

/*
 * This example app shows that an engine can be used independently from a MapView,
 * without any further adaptions. Here we use a SearchEngine to start a category search
 * in Berlin, Germany.
 */
final class ViewController: UIViewController {

    private var searchEngine: SearchEngine!

    override func viewDidLoad() {
        super.viewDidLoad()

        print("HERE SDK version: \(SDKBuildInformation.sdkVersion().versionName)")

        do {
            try searchEngine = SearchEngine()
        } catch let engineInstantiationError {
            fatalError("Failed to initialize engine. Cause: \(engineInstantiationError)")
        }

        searchForCategories()
    }

    private func searchForCategories() {
        let categoryList = [PlaceCategory(id: PlaceCategory.eatAndDrink),
                            PlaceCategory(id: PlaceCategory.shoppingElectronics)]        
        let queryArea = CategoryQuery.Area(areaCenter: GeoCoordinates(latitude: 52.520798,
                                                                      longitude: 13.409408))
        let categoryQuery = CategoryQuery(categoryList, area: queryArea)
        let searchOptions = SearchOptions(languageCode: LanguageCode.enUs,
                                          maxItems: 30)

        _ = searchEngine.search(categoryQuery: categoryQuery,
                                options: searchOptions,
                                completion: onSearchCompleted)
    }

    public func onSearchCompleted(error: SearchError?, items: [Place]?) {
        if let searchError = error {
            print("Search Error: \(searchError)")
            return
        }

        // If error is nil, it is guaranteed that the items will not be nil.
        showDialog(title: "Search Result", message: "\(items!.count) result(s) found. See log for details.")

        for place in items! {
            let addressText = place.address.addressText
            print(addressText)
        }
    }

    private func showDialog(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
