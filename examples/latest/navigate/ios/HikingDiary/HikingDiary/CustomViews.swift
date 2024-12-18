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

// CustomMenuButton is a reusable SwiftUI view that displays a button with a menu icon.
struct CustomMenuButton: View {
    // Use @Binding to connect to the state from the parent view.
    @Binding var showMenu: Bool
    
    var body: some View {
        Button(action: {
            showMenu.toggle()
        }) {
            Image(systemName: "line.horizontal.3")
                .resizable()
                .frame(width: 25, height: 25)
        }
        .padding()
    }
}

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

/// A customizable slider switch with drag and tap gestures for toggling states.
struct CustomSliderSwitch: View {
    @Binding var isOn: Bool
    @State private var offset: CGFloat = 0.0
    
    private let switchWidth: CGFloat = 80
    private let switchHeight: CGFloat = 40
    private let thumbDiameter: CGFloat = 36
    
    private let onColor = Color(red: 0, green: 144 / 255, blue: 138 / 255)
    private let offColor = Color.gray
    private let thumbOnColor = Color.white
    private let thumbOffColor = Color.white
    
    // Action closures
    var onAction: () -> Void
    var offAction: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Capsule()
                .fill(isOn ? onColor : offColor)
                .frame(width: switchWidth, height: switchHeight)
            
            // Thumb
            Circle()
                .fill(isOn ? thumbOnColor : thumbOffColor)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .offset(x: offset)
                .shadow(radius: 2)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            let newOffset = gesture.translation.width
                            let minOffset = -(switchWidth / 2 - thumbDiameter / 2)
                            let maxOffset = (switchWidth / 2 - thumbDiameter / 2)
                            offset = min(max(newOffset + (isOn ? maxOffset : minOffset), minOffset), maxOffset)
                        }
                        .onEnded { _ in
                            let midPoint = CGFloat(0)
                            let wasOn = isOn
                            isOn = offset > midPoint
                            withAnimation {
                                offset = isOn ? (switchWidth / 2 - thumbDiameter / 2) : -(switchWidth / 2 - thumbDiameter / 2)
                            }
                            if wasOn != isOn {
                                if isOn { onAction() } else { offAction() }
                            }
                        }
                )
        }
        .onAppear {
            offset = isOn ? (switchWidth / 2 - thumbDiameter / 2) : -(switchWidth / 2 - thumbDiameter / 2)
        }
        .frame(height: switchHeight)
    }
}

// A custom text view for displaying and updating text in the UI.
struct CustomTextView: View {
    var message: String
    var textViewBackgroundColor = Color(red: 0, green: 144 / 255, blue: 138 / 255).opacity(0.8)
    
    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding()
            .background(textViewBackgroundColor)
            .cornerRadius(8)
            .multilineTextAlignment(.center)
    }
}

