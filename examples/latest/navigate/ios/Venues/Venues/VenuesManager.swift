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

public class VenuesManager: UIView {
    @IBOutlet private weak var venuesTable: UITableView!
    @IBOutlet private var view: UIView!
    private weak var venueMap: VenueMap?
    private weak var mapView: MapView?
    private var venues: [Venue] = []
    private let venueCellId = "VenueTableViewCell"

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
        frameworkBundle.loadNibNamed("VenuesManager", owner: self, options: nil)
        addSubview(view)
        view.frame = bounds

        venuesTable.dataSource = self
        venuesTable.delegate = self
        let venueCell = UINib(nibName: venueCellId, bundle: nil)
        venuesTable.register(venueCell, forCellReuseIdentifier: venueCellId)

        isHidden = true
    }

    public func setup(_ venueMap: VenueMap?, mapView: MapView?) {
        removeVenueMapDelegate()
        self.mapView = mapView
        if let venueMap = venueMap {
            self.venueMap = venueMap
            venueMap.addVenueLifecycleDelegate(self)
            updateVenueList()
        }
    }

    func removeVenueMapDelegate() {
        if let venueMap = venueMap {
            venueMap.removeVenueLifecycleDelegate(self)
        }
    }

    func updateVenueList() {
        if let venueMap = venueMap {
            venues = Array(venueMap.venues.values)
            venues.sort {
                $0.venueModel.id < $1.venueModel.id
            }
            venuesTable.reloadData()
        }
    }
}

extension VenuesManager: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return venues.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let venue = venues[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: venueCellId) as? VenueTableViewCell {
            cell.setup(venueMap, venue: venue)
            return cell
        }

        return UITableViewCell()
    }
}

extension VenuesManager: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let venueMap = venueMap {
            venueMap.selectedVenue = venues[indexPath.row]
            if let center = venueMap.selectedVenue?.venueModel.center {
                mapView?.camera.lookAt(point: center)
            }
            isHidden = true
        }
    }
}

extension VenuesManager: VenueLifecycleDelegate {
    public func onVenueAdded(venue: Venue) {
        updateVenueList()
    }

    public func onVenueRemoved(venueId: Int32) {
        updateVenueList()
    }
}
