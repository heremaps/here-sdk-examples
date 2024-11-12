/*
 * Copyright (C) 2024 HERE Europe B.V.
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

/*
 * A collection of resuable views with custom styling and layout.
 */

// A reusable button to keep the layout clean.
struct CustomButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
                .background(Color(red: 0, green: 182/255, blue: 178/255))
                .foregroundColor(.white)
                .cornerRadius(5)
        }
    }
}

// A reusable toggle button to keep the layout clean.
struct CustomToggleButton: View {
    @State private var isOn: Bool = false
    var onLabel: String
    var offLabel: String
    var onAction: () -> Void
    var offAction: () -> Void
    
    var body: some View {
        Button(action: {
            isOn.toggle()
            if isOn {
                onAction()
            } else {
                offAction()
            }
        }) {
            Text(isOn ? onLabel : offLabel)
                .padding()
                .background(Color(red: 0, green: 182/255, blue: 178/255))
                .foregroundColor(.white)
                .cornerRadius(5)
        }
    }
}

struct CustomTextView: View {
    var message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .multilineTextAlignment(.center)
    }
}
