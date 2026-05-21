/*
 * Copyright (C) 2025-2026 HERE Europe B.V.
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

import UIKit
import heresdk


// GradientButton subclass for gradient background support
class GradientButton: UIButton {
    private var gradientLayer: CAGradientLayer?

    func setGradientBackground(startColor: UIColor, endColor: UIColor) {
        gradientLayer?.removeFromSuperlayer()
        let gradient = CAGradientLayer()
        gradient.colors = [startColor.cgColor, endColor.cgColor]
        // 45 degree angle: startPoint (0,1) to endPoint (1,0)
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        gradient.frame = bounds
        gradient.cornerRadius = layer.cornerRadius
        layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
        gradientLayer?.cornerRadius = layer.cornerRadius
    }
}

public class IndoorRoutingUIController: UIViewController {

    public enum States {
        case ROUTING_CLOSED
        case SPACE_SELECTED
        case ROUTING_UI
        case SHOW_SPACE_LIST
    }
    
    public enum SpaceSelection {
        case SELECTING_ARRIVAL_SPACE
        case SELECTING_DEPARTURE_SPACE
    }
    
    public var currentState: States!
    public var spaceSelectionState: SpaceSelection!
    
    public var selectedArrivalGeometry: heresdk.VenueGeometry? {
        didSet {
            if isViewLoaded, let data = selectedArrivalGeometry {
                addDynamicContentToSpaceSelectionView(with: data)
                currentState = .SPACE_SELECTED
                loadExpectedView()
            }
        }
    }
    
    public var selectedDepartureGeometry: VenueGeometry?
    public var selectedVenue: Venue!
    public var mapview: MapView!
    public var departureLable: UILabel!
    public var indoorRoutingHandler: IndoorRoutingHandler!
    public var topologyButton: UIImageView!
    public var topologyVisibility: Bool!
    public var venueTapHandler: VenueTapHandler!
    var markerImage: MapImage?
    var marker: MapMarker?
    var iconApplied: Bool = false
    // Container View
    var containerView: UIView!
        
    // subviews
    var spaceSelectionView: UIView!
    var indoorRoutingView: UIView!
    var spaceListView: UIView!
    private var handlerView: UIView!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var currentHeight: CGFloat = 150 // Default height
    private let defaultHeight: CGFloat = 150
    private let expandedHeight: CGFloat = 800
    
    private var arrivalLable: UILabel!
    private var customSearchBar: IndoorMap.SearchBar!
    private var geometryTableView: UITableView!
    private var allGeometries: [VenueGeometry] = []
    private var filteredGeometries: [VenueGeometry] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        
        setupContainerView()
        setupHandlerView()
        setupSpaceSelectionView()
        
        if let data = selectedArrivalGeometry {
            addDynamicContentToSpaceSelectionView(with: data)
        }
        currentState = .SPACE_SELECTED
        loadExpectedView()
    }
    
    func setupContainerView() {
        containerView = UIView(frame: view.bounds)
        spaceSelectionView = UIView(frame: containerView.bounds)
        indoorRoutingView = UIView(frame: containerView.bounds)
        spaceListView = UIView(frame: containerView.bounds)
        view.addSubview(containerView)
    }
    
    private func setupHandlerView() {
        handlerView = UIView()
        handlerView.backgroundColor = UIColor.systemGray4
        handlerView.layer.cornerRadius = 3
        handlerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(handlerView)
        NSLayoutConstraint.activate([
            handlerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            handlerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handlerView.widthAnchor.constraint(equalToConstant: 40),
            handlerView.heightAnchor.constraint(equalToConstant: 6)
        ])
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        view.addGestureRecognizer(panGestureRecognizer)
    }
    
    func setupSpaceSelectionView() {
        containerView.addSubview(spaceSelectionView)
    }
    
    
    func setupIndoorRoutingView() {
        containerView.addSubview(indoorRoutingView)
        addDynamicContentToIndoorRoutingView()
    }
    
    func setupSpaceListView() {
        containerView.addSubview(spaceListView)
        addDynamicContentToSpaceList()
    }

    public func addDynamicContentToSpaceSelectionView(with data: VenueGeometry) {
        
        spaceSelectionView.subviews.forEach { $0.removeFromSuperview() }
        // Label 1
        let selectedSpaceName = UILabel()
        selectedSpaceName.numberOfLines = 0
        selectedSpaceName.lineBreakMode = .byWordWrapping
        let name = data.name
        if(!name.isEmpty) {
            selectedSpaceName.text = data.name + ", " + data.level.name
        } else {
            let center = data.center
            let lat = String(format: "%.5f", center.latitude)
            let lon = String(format: "%.5f", center.longitude)
            selectedSpaceName.text = "\(lat), \(lon)" + ", " + data.level.name
        }
        
        selectedSpaceName.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        selectedSpaceName.translatesAutoresizingMaskIntoConstraints = false
        
        // Label 2
        let selectedSpaceAddress = UILabel()
        selectedSpaceAddress.text = data.internalAddress?.address
        selectedSpaceAddress.font = UIFont.systemFont(ofSize: 16)
        selectedSpaceAddress.translatesAutoresizingMaskIntoConstraints = false
        
        // Button
        let directionButton = GradientButton(type: .system)
        directionButton.setTitle("Directions", for: .normal)
        directionButton.setTitleColor(.black, for: .normal)
        directionButton.translatesAutoresizingMaskIntoConstraints = false
        directionButton.backgroundColor = .clear // Set to clear to show gradient
        directionButton.layer.cornerRadius = 20
        directionButton.clipsToBounds = true
        directionButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        directionButton.setGradientBackground(
            startColor: UIColor(hex: "#69AdF8"),
            endColor: UIColor(hex: "#53D9D0")
        )
        directionButton.addTarget(self, action: #selector(setCurrentStateRoutingUI), for: .touchUpInside)

        // Close image
        let closeButtonImageView = UIImageView()
        closeButtonImageView.translatesAutoresizingMaskIntoConstraints = false
        closeButtonImageView.contentMode = .scaleAspectFit
        closeButtonImageView.clipsToBounds = true
        closeButtonImageView.isUserInteractionEnabled = true
        closeButtonImageView.image = UIImage(systemName: "xmark")
        closeButtonImageView.tintColor = .black
        closeButtonImageView.layer.cornerRadius = 12
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SpaceSelectioncloseTapped))
        closeButtonImageView.addGestureRecognizer(tapGestureRecognizer)

        
        // Add to spaceSelectionView
        spaceSelectionView.addSubview(selectedSpaceName)
        spaceSelectionView.addSubview(selectedSpaceAddress)
        spaceSelectionView.addSubview(directionButton)
        spaceSelectionView.addSubview(closeButtonImageView)
        
        // Constraints
        NSLayoutConstraint.activate([
            selectedSpaceName.topAnchor.constraint(equalTo: spaceSelectionView.topAnchor, constant: 20),
            selectedSpaceName.leadingAnchor.constraint(equalTo: spaceSelectionView.leadingAnchor, constant: 20),
            selectedSpaceName.trailingAnchor.constraint(equalTo: spaceSelectionView.trailingAnchor, constant: -20),

            selectedSpaceAddress.topAnchor.constraint(equalTo: selectedSpaceName.bottomAnchor, constant: 5),
            selectedSpaceAddress.leadingAnchor.constraint(equalTo: spaceSelectionView.leadingAnchor, constant: 20),

            directionButton.topAnchor.constraint(equalTo: selectedSpaceAddress.bottomAnchor, constant: 10),
            directionButton.leadingAnchor.constraint(equalTo: spaceSelectionView.leadingAnchor, constant: 20),
            directionButton.trailingAnchor.constraint(equalTo: spaceSelectionView.trailingAnchor, constant: -20),
            //directionButton.bottomAnchor.constraint(equalTo: spaceSelectionView.bottomAnchor, constant: -10),

            closeButtonImageView.topAnchor.constraint(equalTo: spaceSelectionView.topAnchor, constant: 20),
            closeButtonImageView.trailingAnchor.constraint(equalTo: spaceSelectionView.trailingAnchor, constant: -20),
            closeButtonImageView.widthAnchor.constraint(equalToConstant: 25),
            closeButtonImageView.heightAnchor.constraint(equalToConstant: 25)

        ])
    }
    
    func addDynamicContentToIndoorRoutingView() {
        // Remove previous subviews to avoid stacking
        indoorRoutingView.subviews.forEach { $0.removeFromSuperview() }
        // departure section
        let departureView = UIView()
        departureView.translatesAutoresizingMaskIntoConstraints = false
        let departureIcon = UIImageView()
        departureIcon.translatesAutoresizingMaskIntoConstraints = false
        departureIcon.contentMode = .scaleAspectFit
        departureIcon.clipsToBounds = true
        departureIcon.image = UIImage(systemName: "smallcircle.filled.circle")
        departureIcon.tintColor = .black
        
        // Remove departureLable from previous superview if needed
        departureLable = UILabel()
        departureLable.translatesAutoresizingMaskIntoConstraints = false
        departureLable.textColor = UIColor(hex: "#53D9D0")
        departureLable.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        departureLable.numberOfLines = 0
        departureLable.lineBreakMode = .byWordWrapping
        departureLable.text = "Choose a starting point"
        departureLable.isUserInteractionEnabled = true
        let departureTap = UITapGestureRecognizer(target: self, action: #selector(departureLabelTapped))
        
        departureView.addSubview(departureIcon)
        departureView.addSubview(departureLable)
        departureView.isUserInteractionEnabled = true
        departureView.addGestureRecognizer(departureTap)
        
        NSLayoutConstraint.activate([
            departureIcon.leadingAnchor.constraint(equalTo: departureView.leadingAnchor, constant: 10),
            departureIcon.topAnchor.constraint(equalTo: departureView.topAnchor, constant: 10),
            departureIcon.bottomAnchor.constraint(equalTo: departureView.bottomAnchor, constant: -10),
            departureIcon.widthAnchor.constraint(equalToConstant: 20),
            departureIcon.heightAnchor.constraint(equalToConstant: 20),
            departureLable.leadingAnchor.constraint(equalTo: departureIcon.trailingAnchor, constant: 5),
            departureLable.topAnchor.constraint(equalTo: departureIcon.topAnchor),
            departureLable.bottomAnchor.constraint(equalTo: departureIcon.bottomAnchor),
            departureLable.trailingAnchor.constraint(equalTo: departureView.trailingAnchor, constant: -5)
        ])
        // separator line
        let separatorView = UIView()
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = .systemGray6
        
        // arrival section
        let arrivalView = UIView()
        arrivalView.translatesAutoresizingMaskIntoConstraints = false
        let arrivalIcon = UIImageView()
        arrivalIcon.translatesAutoresizingMaskIntoConstraints = false
        arrivalIcon.contentMode = .scaleAspectFit
        arrivalIcon.clipsToBounds = true
        arrivalIcon.image = UIImage(named: "indoor_destination")
        arrivalIcon.tintColor = .black
        
        arrivalLable = UILabel()
        arrivalLable.translatesAutoresizingMaskIntoConstraints = false
        arrivalLable.numberOfLines = 0
        arrivalLable.lineBreakMode = .byWordWrapping
        arrivalLable.textColor = .black
        arrivalLable.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        // Set arrival label text based on selectedSpace
        if let space = selectedArrivalGeometry {
            let name = space.name
            if(!name.isEmpty) {
                arrivalLable.text = name + ", " + space.level.name
            } else {
                let center = space.center
                let lat = String(format: "%.5f", center.latitude)
                let lon = String(format: "%.5f", center.longitude)
                arrivalLable.text = "Lat: \(lat), Lon: \(lon)"
            }
        }
        arrivalView.addSubview(arrivalIcon)
        arrivalView.addSubview(arrivalLable)
        let arrivalTap = UITapGestureRecognizer(target: self, action: #selector(arrivalLabelTapped))
        arrivalView.isUserInteractionEnabled = true
        arrivalView.addGestureRecognizer(arrivalTap)
        
        NSLayoutConstraint.activate([
            arrivalIcon.leadingAnchor.constraint(equalTo: arrivalView.leadingAnchor, constant: 10),
            arrivalIcon.topAnchor.constraint(equalTo: arrivalView.topAnchor, constant: 10),
            arrivalIcon.bottomAnchor.constraint(equalTo: arrivalView.bottomAnchor, constant: -10),
            arrivalIcon.widthAnchor.constraint(equalToConstant: 20),
            arrivalIcon.heightAnchor.constraint(equalToConstant: 20),
            arrivalLable.leadingAnchor.constraint(equalTo: arrivalIcon.trailingAnchor, constant: 5),
            arrivalLable.topAnchor.constraint(equalTo: arrivalIcon.topAnchor),
            arrivalLable.bottomAnchor.constraint(equalTo: arrivalIcon.bottomAnchor),
            arrivalLable.trailingAnchor.constraint(equalTo: arrivalView.trailingAnchor, constant: -5)
        ])
        
        // Close image
        let closeButtonImageView = UIImageView()
        closeButtonImageView.translatesAutoresizingMaskIntoConstraints = false
        closeButtonImageView.contentMode = .scaleAspectFit
        closeButtonImageView.clipsToBounds = true
        closeButtonImageView.isUserInteractionEnabled = true
        closeButtonImageView.image = UIImage(systemName: "xmark")
        closeButtonImageView.tintColor = .black
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(IndoorRoutingCloseTapped))
        closeButtonImageView.addGestureRecognizer(tapGestureRecognizer)
        
        indoorRoutingView.addSubview(departureView)
        indoorRoutingView.addSubview(separatorView)
        indoorRoutingView.addSubview(arrivalView)
        indoorRoutingView.addSubview(closeButtonImageView)
        
        NSLayoutConstraint.activate([
            departureView.leadingAnchor.constraint(equalTo: indoorRoutingView.leadingAnchor),
            departureView.trailingAnchor.constraint(equalTo: indoorRoutingView.trailingAnchor, constant: -40),
            departureView.topAnchor.constraint(equalTo: indoorRoutingView.topAnchor, constant: 20),
            departureView.heightAnchor.constraint(equalToConstant: 40),
            separatorView.topAnchor.constraint(equalTo: departureView.bottomAnchor),
            separatorView.leadingAnchor.constraint(equalTo: indoorRoutingView.leadingAnchor, constant: 20),
            separatorView.trailingAnchor.constraint(equalTo: indoorRoutingView.trailingAnchor, constant: -80),
            separatorView.heightAnchor.constraint(equalToConstant: 2),
            arrivalView.leadingAnchor.constraint(equalTo: indoorRoutingView.leadingAnchor),
            arrivalView.trailingAnchor.constraint(equalTo: indoorRoutingView.trailingAnchor, constant: -40),
            arrivalView.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
            arrivalView.heightAnchor.constraint(equalToConstant: 40),
            closeButtonImageView.topAnchor.constraint(equalTo: indoorRoutingView.topAnchor, constant: 20),
            closeButtonImageView.trailingAnchor.constraint(equalTo: indoorRoutingView.trailingAnchor, constant: -20),
            closeButtonImageView.widthAnchor.constraint(equalToConstant: 25),
            closeButtonImageView.heightAnchor.constraint(equalToConstant: 25),
        ])
    }
    
    
    @IBAction func SpaceSelectioncloseTapped(_ sender: Any) {
        currentState = .ROUTING_CLOSED
        if iconApplied {
            if let currentMarker = marker {
                mapview.mapScene.removeMapMarker(currentMarker)
                iconApplied = false
            }
        }
        dismissBottomSheet()
    }
    
    @IBAction func IndoorRoutingCloseTapped(_ sender: Any) {
        currentState = .SPACE_SELECTED
        loadExpectedView()
        topologyVisibility = false
        if selectedVenue.venueModel.topologies.isEmpty == false {
            topologyButton.image = UIImage(named: "topology-default")
            topologyButton.isHidden = false
        }
        if selectedArrivalGeometry?.lookupType == .icon {
            if let image = getMarkerImage() {
                marker = MapMarker(at: selectedArrivalGeometry!.center,
                                   image: image,
                                   anchor: Anchor2D(horizontal: 0.5, vertical: 1.0))
                if let marker = marker {
                    mapview.mapScene.addMapMarker(marker)
                    iconApplied = true
                }
            }
        }
        indoorRoutingHandler.stopRouting()
    }
    
    func getMarkerImage() -> MapImage? {
        if let image = markerImage {
            return image
        }

        // Get an image for MapMarker.
        if let image = UIImage(named: "poi.png"), let pngData = image.pngData() {
            markerImage = MapImage(pixelData: pngData, imageFormat: .png)
        }
        return markerImage
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        if currentState == .SHOW_SPACE_LIST {
            guard let superview = view.superview else { return }
            let translation = gesture.translation(in: superview)
            switch gesture.state {
            /*case .changed:
                let newHeight = max(defaultHeight, min(expandedHeight, currentHeight - translation.y))
                view.frame.origin.y = superview.frame.height - newHeight
                view.frame.size.height = newHeight*/
            case .ended:
                let velocity = gesture.velocity(in: superview).y
                if velocity > 0 {
                    collapseBottomSheet()
                }
            default:
                break
            }
        }
    }
    
    private func collapseBottomSheet() {
        guard let superview = view.superview else { return }
        currentHeight = defaultHeight
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = superview.frame.height - self.defaultHeight
            self.view.frame.size.height = self.defaultHeight
        }
        
        currentState = .ROUTING_UI
        loadExpectedView()
    }
    
    public func showBottomSheet(height: CGFloat) {
        
        guard let superview = view.superview else { return }
        view.frame = CGRect(x: 0, y: superview.frame.height, width: superview.frame.width, height: height)
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = superview.frame.height - height
        }
    }
    public func dismissBottomSheet() {
        UIView.animate(withDuration: 0.3, animations: {
            self.view.frame.origin.y = self.view.superview!.frame.height
        }) { _ in
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
        currentState = .ROUTING_CLOSED
        topologyVisibility = false
        if selectedVenue.venueModel.topologies.isEmpty == false {
            topologyButton.image = UIImage(named: "topology-default")
            topologyButton.isHidden = false
        }
        venueTapHandler.deselectGeometry()
    }
    
    private func expandBottomSheet() {
        guard let superview = view.superview else { return }
        let fullHeight = superview.frame.height
        UIView.animate(withDuration: 0.3) {
            self.view.frame.origin.y = 0
            self.view.frame.size.height = fullHeight
        }
    }
    
    @objc func setCurrentStateRoutingUI() {
        currentState = .ROUTING_UI
        selectedVenue.isTopologyVisible = false
        topologyButton.isHidden = true
        selectedVenue.setCustomStyle(geometries: [selectedArrivalGeometry!], style: nil, labelStyle: nil)
        setupIndoorRoutingView()
        loadExpectedView()
    }
    
    func loadExpectedView() {
        print("currentState: \(currentState)")
        switch currentState {
        case .ROUTING_CLOSED:
            spaceSelectionView.isHidden = true
            indoorRoutingView.isHidden = true
            spaceListView.isHidden = true
            
        case .SPACE_SELECTED:
            spaceSelectionView.isHidden = false
            indoorRoutingView.isHidden = true
            spaceListView.isHidden = true
            
        case .ROUTING_UI:
            spaceSelectionView.isHidden = true
            indoorRoutingView.isHidden = false
            spaceListView.isHidden = true
        case .SHOW_SPACE_LIST:
            spaceSelectionView.isHidden = true
            indoorRoutingView.isHidden = true
            spaceListView.isHidden = false
        case .none:
            spaceSelectionView.isHidden = true
            indoorRoutingView.isHidden = true
            spaceListView.isHidden = true
        }
    }
    
    @objc private func departureLabelTapped() {
        print("departureLabelTapped")
        spaceSelectionState = .SELECTING_DEPARTURE_SPACE
        showSpaceList()
    }
    
    @objc private func arrivalLabelTapped() {
        spaceSelectionState = .SELECTING_ARRIVAL_SPACE
        showSpaceList()
    }
    
    @objc private func showSpaceList() {
        currentState = .SHOW_SPACE_LIST
        loadExpectedView()
        // Expand bottom sheet to full size
        expandBottomSheet() // Assumes you have this method for expansion
        // Show search bar and geometry list
        print("departureLabelTapped")
        //dismissBottomSheet()
        showBottomSheet(height: 800)
        setupSpaceListView()
    }

    private func addDynamicContentToSpaceList() {
        // Remove previous search bar and table if any
        geometryTableView?.removeFromSuperview()
        // Add search bar
        customSearchBar = IndoorMap.SearchBar()
        customSearchBar.delegate = self
        customSearchBar.translatesAutoresizingMaskIntoConstraints = false
        customSearchBar.placeholder = "Search for Spaces"
        spaceListView.addSubview(customSearchBar)
        NSLayoutConstraint.activate([
            customSearchBar.topAnchor.constraint(equalTo: spaceListView.topAnchor, constant: 5),
            customSearchBar.leadingAnchor.constraint(equalTo: spaceListView.leadingAnchor),
            customSearchBar.trailingAnchor.constraint(equalTo: spaceListView.trailingAnchor),
            customSearchBar.heightAnchor.constraint(equalToConstant: 56)
        ])
        // Add table view
        geometryTableView = UITableView()
        geometryTableView.translatesAutoresizingMaskIntoConstraints = false
        geometryTableView.dataSource = self
        geometryTableView.delegate = self
        spaceListView.addSubview(geometryTableView)
        NSLayoutConstraint.activate([
            geometryTableView.topAnchor.constraint(equalTo: customSearchBar.bottomAnchor, constant: 5),
            geometryTableView.leadingAnchor.constraint(equalTo: spaceListView.leadingAnchor),
            geometryTableView.trailingAnchor.constraint(equalTo: spaceListView.trailingAnchor),
            geometryTableView.bottomAnchor.constraint(equalTo: spaceListView.bottomAnchor)
        ])
        // Load geometries from selectedVenue
        if let venue = selectedVenue {
            allGeometries = venue.venueModel.geometriesByName
            filteredGeometries = allGeometries
            geometryTableView.reloadData()
        }
    }

}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension IndoorRoutingUIController: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredGeometries.count
    }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "GeometryCell")
        let geometry = filteredGeometries[indexPath.row]
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        cell.textLabel?.text = geometry.name + ", " + geometry.level.name
        cell.detailTextLabel?.text = geometry.internalAddress?.address
        return cell
    }
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let geometry = filteredGeometries[indexPath.row]
        if spaceSelectionState == .SELECTING_DEPARTURE_SPACE {
            selectedDepartureGeometry = geometry
            let name = geometry.name
            if (!name.isEmpty){
                departureLable.text = name + ", " + geometry.level.name
            } else if let center = selectedDepartureGeometry?.center {
                let lat = String(format: "%.5f", center.latitude)
                let lon = String(format: "%.5f", center.longitude)
                departureLable.text = "Lat: \(lat), Lon: \(lon)" + ", " + geometry.level.name
            }
        } else {
            selectedArrivalGeometry = geometry
            let name = geometry.name
            if (!name.isEmpty){
                arrivalLable.text = name + ", " + geometry.level.name
            } else if let center = selectedArrivalGeometry?.center {
                let lat = String(format: "%.5f", center.latitude)
                let lon = String(format: "%.5f", center.longitude)
                arrivalLable.text = "Lat: \(lat), Lon: \(lon)" + ", " + geometry.level.name
            }
        }
        
        selectedVenue.selectedLevel = selectedDepartureGeometry!.level
        mapview.camera.lookAt(point: selectedDepartureGeometry!.center)
        
        indoorRoutingHandler.startRouting(source: selectedDepartureGeometry!, destination: selectedArrivalGeometry!)
        
        // Dismiss keyboard
        customSearchBar.resignFirstResponder()
        showBottomSheet(height: 150)
        currentState = .ROUTING_UI
        loadExpectedView()
    }
}

// MARK: - UISearchBarDelegate
extension IndoorRoutingUIController: UISearchBarDelegate {
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredGeometries = allGeometries
        } else {
            filteredGeometries = allGeometries.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
        geometryTableView.reloadData()
        searchBar.placeholder = "Search for spaces"
    }
    
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Update the bottom drawer height constraint
        searchBar.text = ""
        if let searchBarTextField = searchBar.value(forKey: "searchField") as? UITextField {
            searchBarTextField.attributedPlaceholder = NSAttributedString(string: "", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18)])
        }
        searchBar.becomeFirstResponder()
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    public func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.text = "Search for spaces"
    }
}


extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
