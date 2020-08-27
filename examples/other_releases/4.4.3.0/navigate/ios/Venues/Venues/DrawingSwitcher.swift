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

// Allows to select a drawing inside a venue trough UI.
public class DrawingSwitcher: UIView {
    @IBOutlet private var contentView: UIView!
    @IBOutlet private weak var selectedDrawingButton: UIButton!
    @IBOutlet private weak var drawingsTableView: UITableView!

    private var venueMap: VenueMap?

    private static let minHeight = CGFloat(30)
    static let maxHeight = CGFloat(140)

    private weak var venueMapDelegate: DrawingSwitcherDelegate?
    private var heightConstraint: NSLayoutConstraint?
    private var drawingNames: [String] = []

    init(_ frame: CGRect) {
        super.init(frame: frame)
        customInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        customInit()
    }

    deinit {
        removeVenueMapDelegate()
    }

    func customInit() {
        let frameworkBundle: Bundle = Bundle(for: DrawingSwitcher.self)
        frameworkBundle.loadNibNamed("DrawingSwitcher", owner: self, options: nil)
        addSubview(contentView)
        // Set up a visual style of DrawingSwitcher
        contentView.frame = bounds
        contentView.layer.borderWidth = 1.0
        contentView.layer.borderColor = UIColor.gray.cgColor
        updateViewForSelectedVenue()

        // Set up a table view with drawing names.
        drawingNames = [String]()
        drawingsTableView.dataSource = self
        drawingsTableView.delegate = self
        drawingsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "DrawingSwitcherCellID")

        // Set up a visual style of title, which contains information about the selected drawing.
        selectedDrawingButton.titleLabel?.numberOfLines = 1
        selectedDrawingButton.titleLabel?.adjustsFontSizeToFitWidth = true
        selectedDrawingButton.titleLabel?.lineBreakMode = NSLineBreakMode.byClipping
        selectedDrawingButton.layer.borderWidth = 1.0
        selectedDrawingButton.layer.borderColor = UIColor.gray.cgColor

        heightConstraint = constraints.first(where: {$0.firstAttribute == .height})
            ?? heightAnchor.constraint(equalToConstant: DrawingSwitcher.minHeight)
        heightConstraint?.isActive = true
        hideView()
    }

    func hideView() {
        DispatchQueue.main.async {
            self.contentView?.isHidden = true
            self.drawingsTableView?.isHidden = true
            self.updateFrame()
        }
    }

    func removeVenueMapDelegate() {
        if let venueMap = venueMap, let venueMapDelegate = venueMapDelegate {
            venueMap.removeVenueSelectionDelegate(venueMapDelegate)
            venueMap.removeDrawingSelectionDelegate(venueMapDelegate)
        }
    }

    func updateViewForSelectedVenue() {
        if venueMap == nil {
            hideView()
            return
        }

        if let venue = venueMap?.selectedVenue {
            updateDrawing(forVenue: venue)
        }
    }

    // Update this DrawingSwitcher with a new venue.
    func updateDrawing(forVenue venue: Venue) {
        // Make DrawingSwitcher invisible if there is less then 2 drawings in the venue.
        if venue.venueModel.drawings.count < 2 {
            hideView()
            return
        }

        DispatchQueue.main.async {
            // Set a name for the selected drawing to the title.
            self.contentView.isHidden = false
            let nameProp: Property? = venue.selectedDrawing.properties["name"]
            let name: String? = nameProp?.string
            self.selectedDrawingButton?.setTitle(name, for: UIControl.State.normal)

            // Get names of drawings and add them to the drawingNames variable.
            self.drawingNames.removeAll()
            let drawings: [VenueDrawing] = venue.venueModel.drawings
            for drawing in drawings {
                self.drawingNames.append(drawing.properties["name"]?.string ?? "")
            }

            self.drawingsTableView?.reloadData()
        }
    }

    public func setVenueMap(_ venueMap: VenueMap?) {
        // Remove old venue map delegates.
        removeVenueMapDelegate()
        // Set VenueMap for this DrawingSwitcher.
        if let venueMap = venueMap {
            self.venueMap = venueMap
            let delegate = DrawingSwitcherDelegate(drawingSwitcher: self)
            venueMap.addVenueSelectionDelegate(delegate)
            venueMap.addDrawingSelectionDelegate(delegate)
            venueMapDelegate = delegate
            updateViewForSelectedVenue()
        }
    }

    @IBAction private func onDrawingButtonClick(withSender: Any) {
        if drawingNames.count > 1 {
            // Show or hide the table view with drawings.
            drawingsTableView.isHidden = !drawingsTableView.isHidden
        } else {
            drawingsTableView.isHidden = true
        }

        updateFrame()
    }

    func updateFrame() {
        heightConstraint?.constant = drawingsTableView.isHidden
            ? DrawingSwitcher.minHeight
            : DrawingSwitcher.maxHeight
    }
}

extension DrawingSwitcher: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return drawingNames.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell =
            tableView.dequeueReusableCell(withIdentifier: "DrawingSwitcherCellID", for: indexPath)

        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.textAlignment = NSTextAlignment.center
        cell.textLabel?.text = drawingNames[indexPath.row]

        return cell
    }
}

extension DrawingSwitcher: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let drawingIndex: Int = indexPath.row
        if let venue = venueMap?.selectedVenue {
            // Set the selected drawing when a user clicks on the item in the table view.
            let drawing: VenueDrawing = venue.venueModel.drawings[drawingIndex]
            venue.selectedDrawing = drawing
            // Hide the table view.
            drawingsTableView.isHidden = true
            updateFrame()
        }
    }
}
