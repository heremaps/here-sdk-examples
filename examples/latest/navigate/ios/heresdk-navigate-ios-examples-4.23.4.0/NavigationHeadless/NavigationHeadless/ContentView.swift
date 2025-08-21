/*
 * Copyright (C) 2025 HERE Europe B.V.
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

struct ContentView: View {
    
    @StateObject private var navigationHeadlessExample = NavigationHeadlessExample()
    
    var body: some View {
         // Show the views on top of each other.
         ZStack(alignment: .top) {
             VStack {
                 CustomText(title: navigationHeadlessExample.speedLimitTextView)
                 CustomText(title: navigationHeadlessExample.roadNameTextView)
                 CustomText(title: navigationHeadlessExample.timerTextView)
             }
         }
         .onAppear {
             // ContentView appeared, now we init the example.
             Task {
                 await navigationHeadlessExample.startGuidanceExample()
             }
         }
         .onDisappear {
             navigationHeadlessExample.stopTimer()
         }
     }
}

// A reusable View to keep the layout clean.
struct CustomText: View {
    let title: String
    
    var body: some View {
        Text(title)
            .padding()
            .background(Color(red: 0, green: 182/255, blue: 178/255))
            .foregroundColor(.white)
            .cornerRadius(5)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
