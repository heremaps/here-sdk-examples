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

// Allows to select a level inside a venue trough UI.
public class LevelSwitcher: UIView {
    @IBOutlet private var view: UIView!
    @IBOutlet private weak var tableView: UITableView!

    var viewController: ViewController?
    private static let maxHeightConstraintValue: Int32 = 145
    private weak var venueMap: VenueMap?
    private weak var venueMapDelegate: LevelSwitcherDelegate?
     // Array of level names
    private var levels: [AnyHashable] = []
    private var heightConstraint: NSLayoutConstraint?
    private var currentLevelIndex: Int32 = 0

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

    func removeVenueMapDelegate() {
        guard let venueMap = venueMap, let delegate = venueMapDelegate else {
          return
        }
        venueMap.removeVenueSelectionDelegate(delegate)
        venueMap.removeDrawingSelectionDelegate(delegate)
        venueMap.removeLevelSelectionDelegate(delegate)
    }

    func customInit() {
        let frameworkBundle = Bundle(for: LevelSwitcher.self)
        frameworkBundle.loadNibNamed("LevelSwitcher", owner: self, options: nil)
        addSubview(view)
        view.frame = bounds
        view.layer.cornerRadius = view.frame.size.width / 2
        
        tableView.layer.cornerRadius = 20.0
        tableView.layer.masksToBounds = true

        // Set up a table view with level names.
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LevelSwitcherCellID")
        tableView.layer.borderWidth = 1.0
        tableView.layer.borderColor = UIColor.clear.cgColor
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        view.isHidden = true
        
        tableView.separatorStyle = .none

        levels = []
        currentLevelIndex = -1
        heightConstraint = constraints.first(where: {$0.firstAttribute == .height}) ?? heightAnchor.constraint(
            equalToConstant: CGFloat(LevelSwitcher.maxHeightConstraintValue))
        heightConstraint?.isActive = true
    }

    public func setVenueMap(_ map: VenueMap?) {
        // Remove old venue map listeners.
        removeVenueMapDelegate()
        // Set VenueMap for this LevelSwitcher.
        if let venueMap = map {
            self.venueMap = venueMap
            let delegate = LevelSwitcherDelegate(levelSwitcher: self)
            venueMap.addVenueSelectionDelegate(delegate)
            venueMap.addDrawingSelectionDelegate(delegate)
            venueMap.addLevelSelectionDelegate(delegate)
            venueMapDelegate = delegate
            // Cover the case, when there is already a selected Venue in the VenueMap
            if let venue = venueMap.selectedVenue {
                setup(with: venue)
            }
        }
    }

    // Set up a selected venue for this LevelSwitcher.
    func setup(with venue: Venue?) {
        currentLevelIndex = -1

        self.levels.removeAll()
        let drawing = venue?.selectedDrawing
        let levels = drawing?.levels
        // Add the level names in a reversed order.
        levels?.reversed().forEach { level in
            self.levels.append(level.shortName)
        }

        tableView.reloadData()
        heightConstraint?.constant
            = min(tableView.contentSize.height, CGFloat(LevelSwitcher.maxHeightConstraintValue))
        currentLevelIndex = (venue?.selectedLevelIndex) ?? -1
        view.isHidden = currentLevelIndex == -1
        viewController?.levelSwitcherStackView.isHidden = view.isHidden
        setCurrentLevel(currentLevelIndex)
    }
    
    func handleUpArrowTap() {
        // Ensure that the currentLevelIndex is within bounds
        if currentLevelIndex < levels.count - 1 {
            // Calculate the next index to select
            let nextIndexPathForLevelIndex = Int32(levels.count) - self.currentLevelIndex - 2

            // Ensure that the next index is within bounds
            if nextIndexPathForLevelIndex >= 0 {
                let nextSelectedIndexPath = IndexPath(row: Int(nextIndexPathForLevelIndex), section: 0)
                tableView.scrollToRow(at: nextSelectedIndexPath, at: .top, animated: true)
                currentLevelIndex += 1 // Update the currentLevelIndex to reflect the new selected row
            }
        }
    }
    
    func handleDownArrowTap() {
        // Ensure that the currentLevelIndex is within bounds
        if currentLevelIndex > 0 {
            // Calculate the previous index to select (move down by one row)
            let previousIndexPathForLevelIndex = Int32(levels.count) - self.currentLevelIndex

            // Ensure that the previous index is within bounds
            if previousIndexPathForLevelIndex < Int32(levels.count) {
                let previousSelectedIndexPath = IndexPath(row: Int(previousIndexPathForLevelIndex), section: 0)
                tableView.scrollToRow(at: previousSelectedIndexPath, at: .top, animated: true)
                currentLevelIndex -= 1 // Update the currentLevelIndex to reflect the new selected row (move down)
            }
        }
    }

    func getVenueMap() -> VenueMap? {
        return venueMap
    }

    // Select row in a table view for the curently selected level.
    func setCurrentLevel(_ currentLevelIndex: Int32) {
        if currentLevelIndex < 0 || currentLevelIndex >= levels.count {
            return
        }

        self.currentLevelIndex = currentLevelIndex

        // Rows in the LevelSwitcher's table view are presented in the reversed way
        let indexPathForLevelIndex = Int32(levels.count) - self.currentLevelIndex - 1
        let selectedIndexPath = IndexPath(row: Int(indexPathForLevelIndex), section: 0)
        tableView.selectRow(at: selectedIndexPath, animated: true, scrollPosition: .none)
        tableView.scrollToRow(at: selectedIndexPath, at: .none, animated: true)
    }

    // Select a level in the venue.
    func updateLevel(_ levelIndex: Int32) {
        if let venue = venueMap?.selectedVenue {
            venue.selectedLevelIndex = currentLevelIndex
        }
    }
}

extension LevelSwitcher: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return levels.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
        -> UITableViewCell {
        let cell
            = tableView.dequeueReusableCell(withIdentifier: "LevelSwitcherCellID", for: indexPath)
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.text = levels[indexPath.row] as? String

        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor(red: 0.069, green: 0.43, blue: 0.971, alpha: 0.05)
        cell.selectedBackgroundView = bgColorView
        return cell
    }
}

extension LevelSwitcher: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Rows in the LevelSwitcher's table view are presented in the reversed way
        currentLevelIndex = Int32(levels.count - indexPath.row - 1)
        updateLevel(currentLevelIndex)
    }
}
