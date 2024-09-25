/*
 * Copyright (C) 2020-2024 HERE Europe B.V.
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

class SearchBar: UISearchBar {
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonSetup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonSetup()
    }

    private func commonSetup() {
        searchBarStyle = .prominent
        self.isTranslucent = true
        self.backgroundImage = UIImage(named: "searcbar_background")

        let backgroundImageName = "searcbar_background"

        layer.borderWidth = 0.0
        layer.borderColor = UIColor.clear.cgColor

        self.backgroundImage = UIImage(named: backgroundImageName)
        layer.backgroundColor = UIColor.white.cgColor

        let searchBarTextField = self.value(forKey: "searchField") as? UITextField
        searchBarTextField?.font = UIFont.systemFont(ofSize: 18)
        searchBarTextField?.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        searchBarTextField?.heightAnchor.constraint(equalToConstant: 80).isActive = true
        searchBarTextField?.layer.cornerRadius = 20
        searchBarTextField?.layer.masksToBounds = true
        searchBarTextField?.background = UIImage(named: backgroundImageName)
        searchBarTextField?.layer.borderWidth = 1
        searchBarTextField?.layer.borderColor = UIColor.black.cgColor

        if let searchBarTextField = self.value(forKey: "searchField") as? UITextField {
            searchBarTextField.backgroundColor = UIColor.clear

            let placeholderText = "Search for venues"
            let attributedPlaceholder = NSAttributedString(
                string: placeholderText,
                attributes: [
                    NSAttributedString.Key.foregroundColor: UIColor.black,
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18)
                ]
            )

            searchBarTextField.attributedPlaceholder = attributedPlaceholder
            searchBarTextField.background = nil
        }
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric,  height: 80)
    }
}

class BannerViewController: UIViewController {
    
    private let bannerView = UIView()
    private let bannerLabel = UILabel()
    private let closeButtonImageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()

        bannerView.backgroundColor = UIColor(red: 0.812, green: 0, blue: 0.102, alpha: 1)
        bannerView.layer.cornerRadius = 10
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)

        let topConstraint = bannerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 60)
        let leftConstraint = bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10)
        let rightConstraint = bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        let widthConstraint = bannerView.widthAnchor.constraint(equalToConstant: 359)
        let heightConstraint = bannerView.heightAnchor.constraint(equalToConstant: 56)

        NSLayoutConstraint.activate([topConstraint, leftConstraint, rightConstraint, widthConstraint, heightConstraint])

        bannerLabel.textColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        bannerLabel.textAlignment = .left
        bannerLabel.font = UIFont.systemFont(ofSize: 14)
        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        bannerView.addSubview(bannerLabel)

        let leftMarginConstraint = bannerLabel.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 15)
        leftMarginConstraint.isActive = true

        bannerLabel.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor).isActive = true
        bannerLabel.topAnchor.constraint(equalTo: bannerView.topAnchor).isActive = true
        bannerLabel.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor).isActive = true

        closeButtonImageView.image = UIImage(named: "closeButtonImage")
        closeButtonImageView.contentMode = .scaleAspectFit
        closeButtonImageView.isUserInteractionEnabled = true
        closeButtonImageView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.addSubview(closeButtonImageView)

        closeButtonImageView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        closeButtonImageView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        closeButtonImageView.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 12).isActive = true
        closeButtonImageView.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -10).isActive = true

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(closeBanner))
        closeButtonImageView.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc private func closeBanner() {
        bannerView.removeFromSuperview()
    }

    func showErrorBanner(withMessage message: String) {
        bannerLabel.text = message
        view.addSubview(bannerView)
    }
}

class StructureSwitcherAlertController: UIViewController {

    private let structureNames: [String]
    private var buttons: [UIButton] = []
    private var optionSelectedHandler: ((String) -> Void)?

    init(structureNames: [String], optionSelectedHandler: ((String) -> Void)?) {
        self.structureNames = structureNames
        self.optionSelectedHandler = optionSelectedHandler
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let contentView = UIView()
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 10
        view.addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        var maxWidth: CGFloat = 0
        for name in structureNames {
            let size = (name as NSString).size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17.0)])
            maxWidth = max(maxWidth, size.width)
        }

        let padding: CGFloat = 20

        contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -85).isActive = true
        contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -300).isActive = true
        contentView.widthAnchor.constraint(equalToConstant: maxWidth + padding + 20).isActive = true

        let screenSize = UIScreen.main.bounds.size
        let allowMultiline = maxWidth > screenSize.width || contentView.frame.height > screenSize.height

        for (index, name) in structureNames.enumerated() {
            let button = UIButton(type: .system)
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
            button.titleLabel?.numberOfLines = allowMultiline ? 0 : 1
            button.setTitle(name, for: .normal)
            button.contentHorizontalAlignment = .left
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.5
            button.tag = index
            button.addTarget(self, action: #selector(optionSelected(_:)), for: .touchUpInside)
            contentView.addSubview(button)
            buttons.append(button)

            button.translatesAutoresizingMaskIntoConstraints = false
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10).isActive = true
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10).isActive = true
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true

            if index == 0 {
                button.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            } else {
                button.topAnchor.constraint(equalTo: buttons[index - 1].bottomAnchor, constant: 5).isActive = true
            }
            
            if index == structureNames.count - 1 {
                button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
            }
        }
        
        contentView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20).isActive = true
        contentView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: 20).isActive = true
    }

    @objc private func optionSelected(_ sender: UIButton) {
        let selectedName = structureNames[sender.tag]
        optionSelectedHandler?(selectedName)
        dismiss(animated: true, completion: nil)
    }
}

class ViewController: UIViewController, UIGestureRecognizerDelegate, VenueInfoListListenerDelegate {
    @IBOutlet weak var levelSwitcherStackView: UIStackView!
    @IBOutlet weak var viewFrame: UIView!
    @IBOutlet private weak var levelSwitcher: LevelSwitcher!
    @IBOutlet private weak var drawingSwitcher: DrawingSwitcher!
    @IBOutlet private weak var geometryNameLabel: UILabel!
    @IBOutlet private weak var venueSearch: VenueSearch!
    @IBOutlet private weak var indoorRoutingUIConstraint: NSLayoutConstraint!
    @IBOutlet weak var btnDrop: UIButton!
    @IBOutlet weak var bottomDrawerView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var structureSwitcher: UIImageView!
    @IBOutlet weak var structureSwitcherView: UIView!
    @IBOutlet weak var upArrowLvlSwitcher: UIImageView!
    @IBOutlet weak var downArrowLvlSwitcher: UIImageView!
    @IBOutlet weak var topPannelView: UIView!
    @IBOutlet weak var topPannelBackImage: UIImageView!
    @IBOutlet weak var topPannelLbl: UILabel!
    @IBOutlet weak var topPannelTopology: UIImageView!
    private let bannerViewController = BannerViewController()
    @IBOutlet weak var spinnerImg: UIImageView!
    @IBOutlet weak var spinnerView: UIView!
    @IBOutlet weak var handleView: UIView!
    private let customSearchBar = SearchBar()

    var mapView: MapView!
    var mapScheme: MapScheme = .normalDay
    var venueEngine: VenueEngine!
    var moveToVenue: Bool = false
    var venueTapHandler: VenueTapHandler?
    var venueMapList = [String]()
    var selectedVenue : String!
    var searchResult: [VenueGeometry] = []
    var filterType: VenueGeometryFilterType = .name
    var venue: Venue?
    var structureNames: [String] = []
    var venueMap: VenueMap?
    var bottomDrawerHeightConstraint: NSLayoutConstraint!
    var messageLabel: UILabel!
    var searchName = [String]()
    var venueNamesList = [String]()
    var searching = false
    var venueLoaded = false;
    var venueMapDelegate: DrawingSwitcherDelegate?
    var displayVenueName: String!
    var isRotating = false
    var topologyVisibility: Bool = false

    //Label text preference as per user choice
    var labelPref = ["OCCUPANT_NAMES", "SPACE_NAME", "INTERNAL_ADDRESS"]

    // Set value for hrn with your platform catalog HRN value if you want to load non default collection.
    var hrn: String = "YOUR_CATALOG_HRN"

    let displaydata = ["indoor", "rightaccessory", "spacenameimage", "spacerightarrow"]

    override func viewDidLoad() {
        super.viewDidLoad()
        customSearchBar.delegate = self
        structureSwitcher.isUserInteractionEnabled = true
        structureSwitcher.isHidden = true
        handleView.isHidden = true
        topPannelTopology.isHidden = true

        topPannelTopology.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topPannelTopology.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topPannelTopology.widthAnchor.constraint(lessThanOrEqualToConstant: 41),
            topPannelTopology.heightAnchor.constraint(equalToConstant: 52)
        ])

        NSLayoutConstraint.activate([
            handleView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width),
            handleView.heightAnchor.constraint(equalToConstant: 30),
        ])

        let imageTap = UITapGestureRecognizer(target: self, action: #selector(structureSwitcherTapped(sender:)))
        imageTap.delegate = self
        structureSwitcher.addGestureRecognizer(imageTap)

        let topologyTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(topologyIconTapped))
        topPannelTopology.isUserInteractionEnabled = true
        topPannelTopology.addGestureRecognizer(topologyTapGestureRecognizer)

        levelSwitcher.viewController = self

        mapView = MapView(frame: viewFrame.bounds)
        viewFrame.addSubview(mapView)

        // Load the map scene using a map scheme to render the map with.
        mapView.mapScene.loadScene(mapScheme: MapScheme.normalDay, completion: onLoadScene)

        self.tableView.isHidden = false
        self.topPannelView.isHidden = true

        levelSwitcherStackView.layer.cornerRadius = 20.0
        levelSwitcherStackView.layer.masksToBounds = true
        levelSwitcherStackView.isHidden = true;

        let tapBackImageGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleBackTap))
        topPannelBackImage.isUserInteractionEnabled = true
        topPannelBackImage.addGestureRecognizer(tapBackImageGestureRecognizer)

        let uptapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(upArrowTapped))
        upArrowLvlSwitcher.isUserInteractionEnabled = true
        upArrowLvlSwitcher.addGestureRecognizer(uptapGestureRecognizer)

        let downtapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(downArrowTapped))
        downArrowLvlSwitcher.isUserInteractionEnabled = true
        downArrowLvlSwitcher.addGestureRecognizer(downtapGestureRecognizer)

        bottomDrawerView.backgroundColor = .white
        view.addSubview(bottomDrawerView)
        
        levelSwitcherStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(levelSwitcherStackView)
        NSLayoutConstraint.activate([levelSwitcherStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),])
        
        structureSwitcher.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(structureSwitcher)
        NSLayoutConstraint.activate([
            structureSwitcher.topAnchor.constraint(equalTo: levelSwitcherStackView.bottomAnchor, constant: 20),
            structureSwitcher.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Set constraints for the bottom drawer view
        bottomDrawerView.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        bottomDrawerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        bottomDrawerHeightConstraint = bottomDrawerView.heightAnchor.constraint(equalToConstant: 105)
        bottomDrawerHeightConstraint.isActive = true
        bottomDrawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        bottomDrawerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomDrawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            bottomDrawerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            bottomDrawerHeightConstraint,
            bottomDrawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Add a pan gesture recognizer to the bottom drawer view
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        bottomDrawerView.addGestureRecognizer(panGestureRecognizer)

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.addSubview(scrollView)

        // Set constraints for the UIScrollView to fill the bottomDrawerView
        scrollView.leadingAnchor.constraint(equalTo: bottomDrawerView.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: bottomDrawerView.trailingAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: bottomDrawerView.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: bottomDrawerView.bottomAnchor).isActive = true

        customSearchBar.translatesAutoresizingMaskIntoConstraints = false
        customSearchBar.isUserInteractionEnabled = true
        customSearchBar.resignFirstResponder()
        bottomDrawerView.addSubview(customSearchBar)

        let searchBarBottomToTableViewTopConstraint = tableView.topAnchor.constraint(equalTo: customSearchBar.bottomAnchor, constant: 10)
        searchBarBottomToTableViewTopConstraint.isActive = true

        // Set constraints for the UISearchBar at the top of the bottomDrawerView
        customSearchBar.topAnchor.constraint(equalTo: bottomDrawerView.topAnchor).isActive = true
        customSearchBar.leadingAnchor.constraint(equalTo: bottomDrawerView.leadingAnchor).isActive = true
        customSearchBar.trailingAnchor.constraint(equalTo: bottomDrawerView.trailingAnchor).isActive = true

        // Create a spacer view to separate the search bar from the label
        let spacerView = UIView()
        scrollView.addSubview(spacerView)
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        spacerView.topAnchor.constraint(equalTo: customSearchBar.bottomAnchor).isActive = true
        spacerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        spacerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true
        spacerView.heightAnchor.constraint(equalToConstant: 8).isActive = true

        // Add a label to the UIScrollView
        messageLabel = UILabel()
        messageLabel.textAlignment = .center
        messageLabel.textColor = .black
        messageLabel.font = UIFont.systemFont(ofSize: 18)
        scrollView.addSubview(messageLabel)

        // Set constraints for the message label
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.topAnchor.constraint(equalTo: spacerView.bottomAnchor).isActive = true
        messageLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16).isActive = true
        messageLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16).isActive = true
        messageLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16).isActive = true
        
        view.bringSubviewToFront(customSearchBar)
        view.bringSubviewToFront(bottomDrawerView)

        spinnerView.layer.cornerRadius = 20
        spinnerView.isHidden = false
        startRotation()
        
        setWatermarkLocation()
    }
    
    public func setWatermarkLocation() {
        let screenSize = UIScreen.main.bounds.size
        let anchor = Anchor2D(horizontal: 0.0, vertical: 0.0)

        let offsetY: CGFloat
        if screenSize.height <= 700.0 {
            offsetY = 850.0
        } else {
            offsetY = 1250.0
        }

        let offset = Point2D(x: 0.0, y: offsetY)
        mapView.setWatermarkLocation(anchor: anchor, offset: offset)
    }

    @objc func topologyIconTapped() {
        topologyVisibility = !topologyVisibility
        venueEngine.venueMap.selectedVenue?.isTopologyVisible = topologyVisibility
        if(!topologyVisibility) {
            venueTapHandler?.deselectTopology()
        }

        if(topologyVisibility) {
            topPannelTopology.image = UIImage(named: "topology-focused")
        } else {
            topPannelTopology.image = UIImage(named: "topology-default")
        }
    }

    func toggleRotation() {
        if isRotating {
            stopRotation()
        } else {
            startRotation()
        }
    }

    func startRotation() {
        isRotating = true
        rotateView()
    }

    func stopRotation() {
        isRotating = false
    }

    func rotateView() {
        UIView.animate(withDuration: 0.00001, delay: 0, options: .curveLinear, animations: {
            self.spinnerImg.transform = self.spinnerImg.transform.rotated(by: .pi / 30) // Rotate by 6 degrees (adjust as needed)
        }) { _ in
            if self.isRotating {
                self.rotateView()
            }
        }
    }

    @objc func handleBackTap() {
        venueLoaded = false
        selectedVenue = nil
        venueTapHandler?.isGeometryTapped = false;
        searchResult.removeAll()
        structureNames.removeAll()
        searchName = venueNamesList
        customSearchBar.placeholder = "Search for venues"
        levelSwitcher.viewController?.levelSwitcherStackView.isHidden = true
        structureSwitcher.isHidden = true
        topPannelView.isHidden = true
        drawingSwitcher.isHidden = true
        venueEngine.venueMap.selectedVenue?.isTopologyVisible = false
        topPannelTopology.image = UIImage(named: "topology-default")

        // Reset the table view data and reload it
        tableView.reloadData()

        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.553013, longitude: 13.292189, altitude: 500.0))

        bottomDrawerHeightConstraint.constant = 105
        customSearchBar.resignFirstResponder()
        tableView.reloadData()

        // Animate the change in drawer height
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }

        let venueMap = venueEngine.venueMap
        venueMap.removeVenue(venue: venueMap.selectedVenue!)
    }

    func loadStructure(_ structureName: String) {
        if let venue = venue {
            let structures: [VenueDrawing] = venue.venueModel.drawings
            for structure in structures {
                if let name = structure.properties["name"]?.string, name == structureName {
                    venue.selectedDrawing = structure
                }
            }
        }
    }

    @objc func upArrowTapped() {
        // Notify the LevelSwitcher class about the up arrow tap
        levelSwitcher?.handleUpArrowTap()
    }
    @objc func downArrowTapped() {
        // Notify the LevelSwitcher class about the down arrow tap
        levelSwitcher?.handleDownArrowTap()
    }

    @objc func structureSwitcherTapped(sender: UITapGestureRecognizer) {
        let alertController = StructureSwitcherAlertController(structureNames: structureNames) { [weak self] selectedName in
            // Call the loadStructure function based on the selected name
            self?.loadStructure(selectedName)
        }
        alertController.view.tintColor = UIColor.black
        present(alertController, animated: true, completion: nil)
    }

    @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
        let maximumHeight: CGFloat = UIScreen.main.bounds.height - 96 // Use the calculated screen height
        let minimumHeight: CGFloat = 105 // Set the minimum height for the drawer

        switch recognizer.state {
        case .changed:
            let translation = recognizer.translation(in: view)

            // Calculate the new constant for the height constraint based on the gesture translation
            var newHeightConstant = bottomDrawerHeightConstraint.constant - translation.y
            newHeightConstant = max(min(newHeightConstant, maximumHeight), minimumHeight)

            // Apply constraints to limit the height of the drawer
            bottomDrawerHeightConstraint.constant = newHeightConstant

            // Reset the translation to avoid sudden jumps in position
            recognizer.setTranslation(CGPoint.zero, in: view)

        case .ended, .cancelled, .failed:
            // Determine whether to snap the drawer to full screen or to the minimum height
            let midHeight = (UIScreen.main.bounds.height + minimumHeight) / 2
            if bottomDrawerHeightConstraint.constant > midHeight {
                bottomDrawerHeightConstraint.constant = maximumHeight
            } else {
                bottomDrawerHeightConstraint.constant = minimumHeight
                customSearchBar.resignFirstResponder()

                if venueLoaded {
                    customSearchBar.placeholder = "Search for spaces"
                }
                else {
                    customSearchBar.placeholder = "Search for venues"
                }
            }

            // Animate the change in drawer height
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
            
        default:
            break
        }
    }

    @IBAction func onClickDropButton(_ sender: Any) {
        
    }

    func animate(toogle: Bool) {
        if toogle {
            UIView.animate(withDuration: 0.3) {
                
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let venueMap = venueEngine.venueMap
        let venueService = venueEngine.venueService
        venueService.removeServiceDelegate(self)
        venueService.removeVenueDelegate(self)
        venueMap.removeVenueSelectionDelegate(self)
        venueMap.removeVenueSelectionDelegate(self)
        mapView.gestures.tapDelegate = nil
        mapView.gestures.longPressDelegate = nil
    }

    // Completion handler when loading a map scene.
    private func onLoadScene(mapError: MapError?) {
        guard mapError == nil else {
            print("Error: Map scene not loaded, \(String(describing: mapError))")
            return
        }

        // Configure the map.
        let camera = mapView.camera
        camera.lookAt(point: GeoCoordinates(latitude: 52.553013, longitude: 13.292189, altitude: 500.0))
        // Hide the extruded building layer, so that it does not overlap with the venues.
        mapView.mapScene.disableFeatures([MapFeatures.extrudedBuildings])

        // Create a venue engine object. Once the initialization is done, a completion handler
        // will be called.
        do {
            try venueEngine = VenueEngine { [weak self] in self?.onVenueEngineInit() }
        } catch {
            print("SDK Engine not instantiated: \(error)")
        }
    }
    
    private func onVenueEngineInit() {
        // Get VenueService and VenueMap objects.
        let venueMap = venueEngine.venueMap
        let venueService = venueEngine.venueService
        
        // Add needed delegates.
        venueService.addServiceDelegate(self)
        venueService.addVenueDelegate(self)
        venueMap.addVenueSelectionDelegate(self)
        venueMap.addVenueInfoListDelegate(self)
        
        // Connect VenueMap to switchers, to control selected drawing and level in the UI.
        levelSwitcher.setVenueMap(venueMap)
        drawingSwitcher.isHidden = true;
        drawingSwitcher.setVenueMap(venueMap)
        
        // Create a venue tap handler and set it as default tap delegate.
        venueTapHandler = VenueTapHandler(venueEngine: venueEngine,
                                          mapView: mapView,
                                          geometryLabel: geometryNameLabel)
        venueSearch.setup(venueMap, tapHandler: venueTapHandler)
        mapView.gestures.tapDelegate = self
        
        venueService.loadTopologies()
        
        // Start VenueEngine. Once authentication is done, the authentication completion handler
        // will be triggered. Afterwards, VenueEngine will start VenueService. Once VenueService
        // is initialized, VenueServiceListener.onInitializationCompleted method will be called.
        venueEngine.start(callback: {
            error, data in if let error = error {
                print("Failed to authenticate, reason: " + error.localizedDescription)
            }
        })
        if ((hrn != "") && (hrn != "YOUR_CATALOG_HRN"))
        {
            // Set platform catalog HRN
            venueService.setHrn(hrn: hrn)
        }
        
        // Set label text preference
        venueService.setLabeltextPreference(labelTextPref: labelPref)
    }
    
    func updateViewForSelectedVenue() {
        if venueMap == nil {
            return
        }
        
        if let venue = venueMap?.selectedVenue {
            updateDrawing(forVenue: venue)
        }
    }
    
    // Update this DrawingSwitcher with a new venue.
    func updateDrawing(forVenue venue: Venue) {
        DispatchQueue.main.async {
            // Get names of drawings and add them to the drawingNames variable.
            self.structureNames.removeAll()
            let drawings: [VenueDrawing] = venue.venueModel.drawings
            for drawing in drawings {
                self.structureNames.append(drawing.properties["name"]?.string ?? "")
            }
        }
    }
    
    // Touch handler for the button which selects venues by id.
    @IBAction private func loadVenue(_ sender: Any) {
        // Try to parse a venue id.
        if selectedVenue == nil {
            print("Error: No ID selected yet.")
            return
        }
        
        if let id = Int32(selectedVenue) {
            if (venueEngine?.venueService.isInitialized() ?? false) /*&& (id != venueEngine?.venueMap.selectedVenue?.venueModel.id)*/ {
                print("Loading venue \(id).")
                moveToVenue = true
                // Select a venue by id.
                venueEngine?.venueMap.selectVenueAsync(venueId: id, completion: self.onVenueLoadError)
            } else {
                print("Venue service is not initialized! Status: \(String(describing: venueEngine?.venueService.getInitStatus()))")
            }
        }
    }
    
    private func onVenueLoadError(_ error: VenueErrorCode?) {
        var errorMessage: String
        
        switch error {
        case .noNetwork:
            errorMessage = "The device has no internet connectivity"
        case .noMetaDataFound:
            errorMessage = "Meta data not present in platform collection catalog"
        case .hrnMissing:
            errorMessage = "HRN not provided. Please insert HRN"
        case .hrnMismatch:
            errorMessage = "HRN does not match with Auth key & secret"
        case .noDefaultCollection:
            errorMessage = "Default collection missing from platform collection catalog"
        case .mapIdNotFound:
            errorMessage = "Map ID requested is not part of the default collection"
        case .mapDataIncorrect:
            errorMessage = "Map data in collection is wrong"
        case .internalServerError:
            errorMessage = "Internal Server Error"
        case .serviceUnavailable:
            errorMessage = "Requested service is not available currently. Please try after some time"
        case .noMapInCollection:
            errorMessage = "No maps available in the collection"
        default:
            errorMessage = "Unknown Error encountered"
        }
        
        // Ensure bannerViewController is initialized only once
        if bannerViewController.parent == nil {
            bannerViewController.showErrorBanner(withMessage: errorMessage)
            showBannerView()
        }
    }
    
    private func showBannerView() {
        addChild(bannerViewController)
        view.addSubview(bannerViewController.view)
        bannerViewController.didMove(toParent: self)
    }
    
    @IBAction private func onSearchTap(_ sender: Any) {
        venueSearch.isHidden = !venueSearch.isHidden
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        mapView.handleLowMemory()
    }
}

// Tap delegate for MapView
extension ViewController: TapDelegate {
    public func onTap(origin: Point2D) {
        // Otherwise, redirect the event to the venue tap handler.
        venueTapHandler?.onTap(origin: origin)
        
        if ((venueTapHandler?.isGeometryTapped) != false) {
            bottomDrawerHeightConstraint.constant = 180
        }
        else {
            bottomDrawerHeightConstraint.constant = 105
        }
        
        tableView.reloadData()
    }
}

// Delegate for the VenueService event.
extension ViewController: VenueServiceDelegate {
    func onInitializationCompleted(result: VenueServiceInitStatus) {
        if (result == .onlineSuccess) {
            print("Venue Service successfully initialized.")
            venueEngine?.venueMap.getVenueInfoListAsync(completion: self.onVenueLoadError)
        } else {
            print("Venue Service failed to initialize!")
        }
    }
    
    func onVenueServiceStopped() {
        print("Venue Service has stopped.")
    }
}

// Delegate for the venue loading event.
extension ViewController: VenueDelegate {
    func onGetVenueCompleted(venueId: Int32, venueModel: VenueModel?, online: Bool, venueStyle: VenueStyle?) {
        if venueModel == nil {
            print("Loading of venue \(venueId) failed!")
        }
        mapView.camera.zoomTo(zoomLevel: 18)
        
        if (venueModel?.topologies.isEmpty == true) {
            DispatchQueue.main.async {
                self.topPannelTopology.isHidden = true
            }
        } else {
            topPannelTopology.isHidden = false
        }
    }
}

// Delegate for the venue selection event.
extension ViewController: VenueSelectionDelegate {
    func onSelectedVenueChanged(deselectedVenue: Venue?, selectedVenue: Venue?) {
        if let venueModel = selectedVenue?.venueModel {
            if moveToVenue {
                // Move camera to the selected venue.
                mapView.camera.lookAt(point: venueModel.center)
                moveToVenue = false
                venue = venueEngine?.venueMap.selectedVenue
                if let selectedVenue = venueEngine?.venueMap.selectedVenue {
                    searchResult = selectedVenue.venueModel.geometriesByName
                    venueLoaded = true
                    customSearchBar.placeholder = " Search for Spaces"
                    structureSwitcher.isHidden = false
                    levelSwitcherStackView.isHidden = false;
                    topPannelView.isHidden = false
                    tableView.reloadData()
                    stopRotation()
                    spinnerView.isHidden = true
                    
                    if (selectedVenue.venueModel.topologies.isEmpty == true) {
                        DispatchQueue.main.async {
                            self.topPannelTopology.isHidden = true
                        }
                    } else {
                        topPannelTopology.isHidden = false
                    }
                    
                    let drawings: [VenueDrawing] = (venue?.venueModel.drawings)!
                    for drawing in drawings {
                        self.structureNames.append(drawing.properties["name"]?.string ?? "")
                    }
                    
                    for name in structureNames {
                        print(name)
                    }
                    
                } else {
                    print("Selected venue is nil or doesn't have geometries.")
                }
            }
        }
        DispatchQueue.main.async {
        }
        
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if ((venueTapHandler?.isGeometryTapped) != false) {
            return 1;
        } else {
            if venueLoaded {
                return searchResult.count
            } else {
                if searching {
                    return searchName.count;
                } else {
                    return venueNamesList.count;
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if ((venueTapHandler?.isGeometryTapped) != false) {
            return 64
        } else {
            return 64
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if ((venueTapHandler?.isGeometryTapped) != false) {
            let cell = tableView.dequeueReusableCell(withIdentifier: "customCell") as! CustomCell
            cell.indoor.image = UIImage(named: displaydata[2])
            
            if let geometry = venueTapHandler?.selectedGeometry {
                let name = geometry.name
                let attributedText = NSMutableAttributedString()
                let nameAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 20),
                    .foregroundColor: UIColor(red: 0, green: 0.039, blue: 0.098, alpha: 0.8)
                ]
                
                let nameAttributedString = NSAttributedString(string: name, attributes: nameAttributes)
                attributedText.append(nameAttributedString)
                
                if let address = geometry.internalAddress?.address, !address.isEmpty {
                    if attributedText.length > 0 {
                        attributedText.append(NSAttributedString(string: "\n"))
                    }
                    let addressAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14),
                        .foregroundColor: UIColor(red: 0.031, green: 0.09, blue: 0.204, alpha: 0.6)
                    ]
                    let addressAttributedString = NSAttributedString(string: address, attributes: addressAttributes)
                    attributedText.append(addressAttributedString)
                }
                cell.venueLbl.attributedText = attributedText
            } else {
                cell.venueLbl.text = ""
            }
            
            // Assuming you have a UIImageView named "indoor"
            let imageView = cell.indoor
            
            // Set the desired width and height
            let newWidth: CGFloat = 21 // Specify your desired width
            let newHeight: CGFloat = 31 // Specify your desired height
            
            // Update the frame of the image view
            imageView?.frame = CGRect(x: imageView!.frame.origin.x, y: (imageView?.frame.origin.y)!, width: newWidth, height: newHeight)
            
            // Load the image and assign it to the image view
            if let image = UIImage(named: displaydata[2]) {
                imageView?.image = image
            }
            cell.rightaccessory.isHidden = true
            return cell;
            
        } else {
            if venueLoaded {
                let cell = tableView.dequeueReusableCell(withIdentifier: "customCell") as! CustomCell
                cell.indoor.image = UIImage(named: displaydata[2])
                
                let geometry = searchResult[indexPath.row]
                let name = geometry.name + ", " + geometry.level.name
                let address = geometry.internalAddress?.address
                
                // Create an attributed string for the label text
                let attributedText = NSMutableAttributedString()
                let nameAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor(red: 0, green: 0.039, blue: 0.098, alpha: 0.8)
                ]
                let nameAttributedString = NSAttributedString(string: name, attributes: nameAttributes)
                attributedText.append(nameAttributedString)
                
                if let address = address, !address.isEmpty {
                    attributedText.append(NSAttributedString(string: "\n"))
                    // Add the address with a smaller font size
                    let addressAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14),
                        .foregroundColor: UIColor(red: 0, green: 0.039, blue: 0.098, alpha: 0.8)
                    ]
                    let addressAttributedString = NSAttributedString(string: address, attributes: addressAttributes)
                    attributedText.append(addressAttributedString)
                }
                
                // Set the attributed text to your label
                cell.venueLbl.attributedText = attributedText
                
                // Assuming you have a UIImageView named "indoor"
                let imageView = cell.indoor
                
                // Set the desired width and height
                let newWidth: CGFloat = 21 // Specify your desired width
                let newHeight: CGFloat = 31 // Specify your desired height
                
                // Update the frame of the image view
                imageView?.frame = CGRect(x: imageView!.frame.origin.x, y: (imageView?.frame.origin.y)!, width: newWidth, height: newHeight)
                
                // Load the image and assign it to the image view
                if let image = UIImage(named: displaydata[2]) {
                    imageView?.image = image
                }
                
                // Assuming you have a UIImageView named "rightaccessory"
                let imageView1 = cell.rightaccessory
                
                // Set the desired width and height
                let newWidth1: CGFloat = 21 // Specify your desired width
                let newHeight1: CGFloat = 31 // Specify your desired height
                
                // Update the frame of the image view
                imageView1?.frame = CGRect(x: imageView1!.frame.origin.x, y: (imageView1?.frame.origin.y)!, width: newWidth1, height: newHeight1)
                
                // Load the image and assign it to the image view
                if let image1 = UIImage(named: displaydata[3]) {
                    imageView1?.image = image1
                }
                return cell
            } else {
                let cell =  tableView.dequeueReusableCell(withIdentifier: "customCell") as! CustomCell
                if searching {
                    cell.venueLbl.text = searchName[indexPath.row]
                } else {
                    cell.venueLbl.text = String(venueMapList[indexPath.row].dropFirst(6))
                }
                
                let imageView = cell.indoor
                
                // Set the desired width and height
                let newWidth: CGFloat = 20 // Specify your desired width
                let newHeight: CGFloat = 20 // Specify your desired height
                
                // Update the frame of the image view
                imageView?.frame = CGRect(x: imageView!.frame.origin.x, y: (imageView?.frame.origin.y)!, width: newWidth, height: newHeight)
                
                // Load the image and assign it to the image view
                if let image = UIImage(named: displaydata[0]) {
                    imageView?.image = image
                }
                
                // Assuming you have a UIImageView named "rightaccessory"
                let imageView1 = cell.rightaccessory
                
                // Set the desired width and height
                let newWidth1: CGFloat = 12 // Specify your desired width
                let newHeight1: CGFloat = 21 // Specify your desired height
                
                // Update the frame of the image view
                imageView1?.frame = CGRect(x: imageView1!.frame.origin.x, y: (imageView1?.frame.origin.y)!, width: newWidth1, height: newHeight1)
                
                // Load the image and assign it to the image view
                if let image1 = UIImage(named: displaydata[1]) {
                    imageView1?.image = image1
                }
                
                return cell;
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Set constraints for the bottom drawer view
        bottomDrawerView.translatesAutoresizingMaskIntoConstraints = false
        bottomDrawerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        bottomDrawerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        bottomDrawerHeightConstraint = bottomDrawerView.heightAnchor.constraint(equalToConstant: 100) // Set the desired height of the drawer
        bottomDrawerHeightConstraint.isActive = true
        bottomDrawerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        if ((venueTapHandler?.isGeometryTapped) != false) {
            //Do nothing
        } else {
            if venueLoaded {
                let geometry = searchResult[indexPath.row]
                venueTapHandler?.selectGeometry(venue: venue!, geometry: geometry, center: true)
                customSearchBar.resignFirstResponder()
                bottomDrawerHeightConstraint.constant = 105
                customSearchBar.placeholder = "Search for spaces"
            } else {
                if searching {
                    if let index = venueNamesList.firstIndex(of: searchName[indexPath.row]) {
                        if index < venueMapList.count {
                            let venueMapListItem = venueMapList[index]
                            let components = venueMapListItem.components(separatedBy: ":")
                            
                            if components.count >= 2 {
                                let venueName = components[1]
                                displayVenueName = venueName
                                print("Venue Name at Index \(index): \(venueName)")
                            }
                        }
                        selectedVenue = String(venueMapList[index].prefix(5))
                    }
                } else {
                    if indexPath.row < venueMapList.count {
                        let venueMapListItem = venueMapList[indexPath.row]
                        let components = venueMapListItem.components(separatedBy: ":")
                        
                        if components.count >= 2 {
                            let venueName = components[1]
                            displayVenueName = venueName
                            print("Venue Name at IndexPath row \(indexPath.row): \(venueName)")
                        }
                    }
                    selectedVenue = String(venueMapList[indexPath.row].prefix(5))
                }
                
                animate(toogle: false)
                customSearchBar.resignFirstResponder()
                
                if let id = Int32(selectedVenue) {
                    if (venueEngine?.venueService.isInitialized() ?? false) /*&& (id != venueEngine?.venueMap.selectedVenue?.venueModel.id)*/ {
                        print("Loading venue \(id).")
                        // Disable the input UI while a venue loading and selection is in progress.
                        moveToVenue = true
                        // Select a venue by id.
                        venueEngine?.venueMap.selectVenueAsync(venueId: id, completion: self.onVenueLoadError)
                        spinnerView.isHidden = false
                        startRotation()
                        
                        // Define the font and other attributes
                        let fontSize: CGFloat = 20.0
                        let font = UIFont.systemFont(ofSize: fontSize)
                        let textColor = UIColor(red: 0, green: 0.039, blue: 0.098, alpha: 0.8)
                        
                        // Create a paragraph style
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.lineHeightMultiple = 1
                        
                        // Create a dictionary of attributes, including bold font
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold)!, size: fontSize),
                            .foregroundColor: textColor,
                            .paragraphStyle: paragraphStyle
                        ]
                        
                        // Create the attributed text
                        let attributedText = NSAttributedString(string: displayVenueName, attributes: attributes)
                        
                        // Set the attributed text to your label
                        topPannelLbl.attributedText = attributedText
                        
                    } else {
                        print("Venue service is not initialized! Status: \(String(describing: venueEngine?.venueService.getInitStatus()))")
                    }
                }
                
                bottomDrawerHeightConstraint.constant = 105
                customSearchBar.placeholder = "Search for venues"
            }
        }
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchName = venueNamesList.filter({$0.lowercased().prefix(searchText.count) == searchText.lowercased()})
        if venueLoaded {
            if let venue = self.venue {
                let searchText = searchBar.text ?? ""
                if !searchText.isEmpty {
                    searchResult = venue.venueModel.filterGeometry(filter: searchText, filterType: filterType)
                } else {
                    searchResult = venue.venueModel.geometriesByName
                }
            } else {
                searchResult = []
            }
        } else {
            searching = true
        }
        
        tableView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Update the bottom drawer height constraint
        bottomDrawerHeightConstraint.constant = UIScreen.main.bounds.height - 96
        searchBar.text = ""
        if let searchBarTextField = searchBar.value(forKey: "searchField") as? UITextField {
            searchBarTextField.attributedPlaceholder = NSAttributedString(string: "", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18)])
        }
        searchBar.becomeFirstResponder()
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        bottomDrawerHeightConstraint.constant = 105
        searchBar.resignFirstResponder()
        if venueLoaded {
            searchBar.text = "Search for spaces"
        }
        else {
            searchBar.text = "Search for venues"
        }
    }
    
    func onVenueInfoListLoad(venueInfoList: [VenueInfo]) {
        DispatchQueue.main.async { [self] in
            var index: Int
            index = 0
            //Get List of venues info
            let venueInfo:[VenueInfo]? = venueEngine?.venueMap.getVenueInfoList(completion: self.onVenueLoadError)
            if let venueInfo = venueInfo {
                for venueInfo in venueInfo {
                    print("Venue Identifier: \(venueInfo.venueIdentifier)." + " Venue Id: \(venueInfo.venueId)." + " Venue Name: \(venueInfo.venueName).")
                    let venueIdStr = venueInfo.venueIdentifier
                    venueMapList.insert(String(venueIdStr.dropFirst(41) + ":" + (venueInfo.venueName)), at: index)
                    venueNamesList.insert((venueInfo.venueName), at: index)
                    index = index+1
                }
                
                self.tableView.delegate = self
                self.tableView.dataSource = self
                tableView.register(UINib(nibName: "CustomCell", bundle: nil), forCellReuseIdentifier: "customCell")
                bottomDrawerView.addSubview(tableView)
                handleView.isHidden = false
                spinnerView.isHidden = true
                stopRotation()
            }
        }
    }
}
