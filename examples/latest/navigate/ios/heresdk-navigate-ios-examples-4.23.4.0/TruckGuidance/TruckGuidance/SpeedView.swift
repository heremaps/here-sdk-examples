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
// speed data while traversing along a route. The data will be shown by the SpeedView panel.
class SpeedModel: ObservableObject {
    @Published var speedText: String
    @Published var labelText: String
    @Published var outerCircleColor: Color
    @Published var isViewVisible: Bool
    
    init(speedText: String = "n/a",
         labelText: String = "",
         circleColor: Color = .red,
         isViewVisible: Bool = false) {
        self.speedText = speedText
        self.labelText = labelText
        self.outerCircleColor = circleColor
        self.isViewVisible = isViewVisible
    }
}

// A simple view to show the current speed limit or current driving speed.
struct SpeedView: View {
    
    // The model which is updated by the example class when new data is provided by the VisualNavigator.
    @ObservedObject var model: SpeedModel
    
    // The size of the text displayed within the view.
    private let textSize: CGFloat = 18
    
    // The width and height of the container view.
    let w: CGFloat = 60
    let h: CGFloat = 80
    
    var body: some View {
        if model.isViewVisible {
            VStack(spacing: 4) {
                // Render the label text at the top.
                Text(model.labelText)
                    .font(.system(size: textSize, weight: .bold))
                    .foregroundColor(.black)
                
                ZStack {
                    // Outer circle.
                    Circle()
                        .fill(model.outerCircleColor)
                        .frame(width: w, height: w)
                    
                    // Inner circle.
                    Circle()
                        .fill(Color.white)
                        .frame(width: w * 0.63, height: w * 0.63)
                    
                    // Speed Text (centered in inner circle).
                    Text(model.speedText)
                        .font(.system(size: textSize, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .frame(width: w, height: h)
            .background(Color.clear)
        }
    }
}

struct SpeedView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample model for the preview.
        let sampleModel = SpeedModel(
            speedText: "n/a",
            labelText: ""
        )
        
        SpeedView(model: sampleModel)
            .previewLayout(.sizeThatFits)
    }
}
