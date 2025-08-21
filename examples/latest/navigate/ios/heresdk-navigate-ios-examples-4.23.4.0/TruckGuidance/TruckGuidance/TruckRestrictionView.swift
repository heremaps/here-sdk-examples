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
// data while traversing along a route. The data will be shown by the TruckRestrictionView panel.
class TruckRestrictionModel: ObservableObject {
    @Published var restrictionDescription: String?
    @Published var isViewVisible: Bool
    
    init(restrictionDescription: String = "n/a",
         isViewVisible: Bool = false) {
        self.restrictionDescription = restrictionDescription
        self.isViewVisible = isViewVisible
    }
}

// A simple view to show the next TruckRestrictionWarning event.
struct TruckRestrictionView: View {
    
    // The model which is updated by the example class when new data is provided by the VisualNavigator.
    @ObservedObject var model: TruckRestrictionModel
    
    // The width and height of the container view.
    let w: CGFloat = 125
    let h: CGFloat = 60
    
    // Margin for text positioning.
    private let margin: CGFloat = 8
    
    // Corner radius for rounded background.
    private let cornerRadius: CGFloat = 8.0
    
    // Custom background color.
    private let customBackgroundColor = Color(red: 18/255, green: 109/255, blue: 249/255)
    
    var body: some View {
        if model.isViewVisible {
            ZStack(alignment: .leading) {
                // Background rectangle with rounded corners.
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(customBackgroundColor)
                    .frame(width: w, height: h)
                
                // Restriction description text, left-aligned and truncated if too long.
                if let restrictionDescription = model.restrictionDescription, !restrictionDescription.isEmpty {
                    Text(restrictionDescription)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.leading, margin)
                        .frame(width: w - 2 * margin, height: h, alignment: .center)
                }
            }
            .frame(width: w, height: h)
            .background(Color.clear)
        }
    }
}

struct TruckRestrictionView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample model for the preview.
        let sampleModel = TruckRestrictionModel(
            restrictionDescription: "n/a"
        )
        
        TruckRestrictionView(model: sampleModel)
            .previewLayout(.sizeThatFits)
    }
}
