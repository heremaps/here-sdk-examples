/*
* Copyright (C) 2020 HERE Europe B.V.
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

public class VenueSearch: UIView {
    @IBOutlet private weak var searchTextField: UITextField!
    @IBOutlet private weak var searchTypePicker: UIPickerView!
    @IBOutlet private weak var searchResultTable: UITableView!
    @IBOutlet private weak var view: UIView!
    private weak var venueMap: VenueMap?
    private var venue: Venue?
    private var searchResult: [VenueGeometry] = []
    private var filterType: VenueGeometryFilterType = .name
    private var tapHandler: VenueTapHandler?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        customInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }

    deinit {
        removeVenueMapDelegate()
    }

    func customInit() {
        let frameworkBundle = Bundle(for: LevelSwitcher.self)
        frameworkBundle.loadNibNamed("VenueSearch", owner: self, options: nil)
        addSubview(view)
        view.frame = bounds

        searchTextField.returnKeyType = .done
        searchTextField.delegate = self

        searchTypePicker.dataSource = self
        searchTypePicker.delegate = self

        searchResultTable.dataSource = self
        searchResultTable.delegate = self
        searchResultTable.register(UITableViewCell.self, forCellReuseIdentifier: "VenueSearchCellID")

        isHidden = true
    }

    public func setup(_ map: VenueMap?, tapHandler: VenueTapHandler?) {
        removeVenueMapDelegate()
        if let venueMap = map {
            self.venueMap = venueMap
            venueMap.addVenueSelectionDelegate(self)
            venueMap.addVenueLifecycleDelegate(self)
            // Covering the case, when there is already a selected Venue in the VenueMap
            venue = venueMap.selectedVenue
            onSearchTextChanged(self)
        }

        self.tapHandler = tapHandler
    }

    func removeVenueMapDelegate() {
        if let venueMap = venueMap {
            venueMap.removeVenueSelectionDelegate(self)
            venueMap.removeVenueLifecycleDelegate(self)
        }
    }

    @IBAction private func onSearchTextChanged(_ sender: Any) {
        if let venue = self.venue {
            let searchText = searchTextField.text ?? ""
            if !searchText.isEmpty {
                searchResult = venue.venueModel.filterGeometry(filter: searchText, filterType: filterType)
            } else {
                searchResult = venue.venueModel.geometriesByName
            }
        } else {
            searchResult = []
        }
        searchResultTable.reloadData()
    }
}

extension VenueSearch: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchTextField.resignFirstResponder()
        return true
    }
}

extension VenueSearch: UIPickerViewDataSource {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return VenueGeometryFilterType.allCases.count
    }
}

extension VenueSearch: UIPickerViewDelegate {
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch row {
        case 0:
            return "Name"
        case 1:
            return "Address"
        case 2:
            return "Name or Address"
        case 3:
            return "Icon Name"
        default:
            break
        }
        return "Name"
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        filterType = VenueGeometryFilterType.allCases[row]
        onSearchTextChanged(self)
    }
}

extension VenueSearch: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResult.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
        let cell
            = tableView.dequeueReusableCell(withIdentifier: "VenueSearchCellID", for: indexPath)
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        let geometry = searchResult[indexPath.row]
        var name = geometry.name + ", " + geometry.level.name
        if let address = geometry.internalAddress {
            if filterType == .address || filterType == .nameOrAddress {
                name += "\n(Address: " + address.longAddress + ")"
            }
        }
        if filterType == .iconName {
            name += "\n(Icon: " + geometry.labelName + ")"
        }
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.text = name
        return cell
    }
}

extension VenueSearch: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let geometry = searchResult[indexPath.row]
        if let tapHandler = tapHandler, let venue = venue {
            tapHandler.selectGeometry(venue: venue, geometry: geometry, center: true)
            isHidden = true
        }
    }
}

extension VenueSearch: VenueSelectionDelegate {
    public func onSelectedVenueChanged(deselectedVenue: Venue?, selectedVenue: Venue?) {
        venue = selectedVenue
        onSearchTextChanged(self)
    }
}

extension VenueSearch: VenueLifecycleDelegate {
    public func onVenueAdded(venue: Venue) {
    }

    public func onVenueRemoved(venueId: Int32) {
        venue = venueMap?.selectedVenue
        onSearchTextChanged(self)
    }
}
