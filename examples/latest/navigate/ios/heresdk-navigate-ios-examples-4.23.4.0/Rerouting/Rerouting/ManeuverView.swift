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

import SwiftUI

// A model class to be used for data binding. The example class will use this model to update
// maneuevr data while traversing along a route. The data will be shown by the ManeuverView panel.
// By default, the panel is not visible.
class ManeuverModel: ObservableObject {
    @Published var distanceText: String
    @Published var maneuverText: String
    @Published var maneuverIcon: UIImage?
    @Published var roadShieldImage: UIImage?
    @Published var isManeuverPanelVisible: Bool
    
    init(distanceText: String = "",
         maneuverText: String = "",
         maneuverIcon: UIImage? = nil,
         roadShieldImage: UIImage? = nil,
         isManeuverPanelVisible: Bool = false) {
        self.distanceText = distanceText
        self.maneuverText = maneuverText
        self.maneuverIcon = maneuverIcon
        self.roadShieldImage = roadShieldImage
        self.isManeuverPanelVisible = isManeuverPanelVisible
    }
}

// A custom view to show maneuver information when travelling along a route.
struct ManeuverView: View {
    
    // The model which is updated by the example class when new maneuver data is provided by the VisualNavigator.
    @ObservedObject var model: ManeuverModel
    
    private let margin: CGFloat = 8
    private let cornerRadius: CGFloat = 8.0
    private let customBackgroundColor = Color(red: 18/255, green: 109/255, blue: 249/255)
    
    var body: some View {
        if model.isManeuverPanelVisible {            
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(customBackgroundColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack(alignment: .top, spacing: margin) {
                    
                    // Maneuver Icon
                    if let maneuverIcon = model.maneuverIcon {
                        Image(uiImage: maneuverIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                    }
                    
                    VStack(alignment: .leading, spacing: margin / 2) {
                        
                        // Distance Text
                        Text(model.distanceText)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        // Maneuver Text
                        Text(model.maneuverText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    
                    Spacer()
                    
                    // Road Shield Icon (if available)
                    if let roadShieldImage = model.roadShieldImage {
                        Image(uiImage: roadShieldImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(margin)
            }
            .frame(height: 80) // Adjust height as needed
        }
    }
}

struct ManeuverView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample model for the preview
        let sampleModel = ManeuverModel(
            distanceText: "500 m",
            maneuverText: "Turn Right",
            maneuverIcon: UIImage(systemName: "arrow.right"),
            roadShieldImage: UIImage(systemName: "car")
        )
        
        return Group {
            ManeuverView(model: sampleModel)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("ManeuverView Preview")
        }
    }
}
