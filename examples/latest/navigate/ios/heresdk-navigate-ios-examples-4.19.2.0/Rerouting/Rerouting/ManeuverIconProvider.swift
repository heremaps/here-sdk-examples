/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
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

import Foundation
import heresdk
import UIKit

// This class loads all supported maneuver icons available from the HERE Icon Library.
//
// Find the assets here:
// https://github.com/heremaps/here-icons/blob/master/icons/guidance-icons/manoeuvers/
//
// The supported icons can be also found in ManeuverIcons.zip in the root folder of this project.
// For your own aplications, unzip the folder and then drag and drop the ManeuverIcons folder onto
// "Assets.xcassets" in Xcode. You can keep the applied default settings.
// You can then load the SVG icons as UIImage. Image name example: "left-turn.svg".
class ManeuverIconProvider {
    
    var maneuverIconFileNames: [ManeuverAction: String] = [:]
    var maneuverIcons: [ManeuverAction: UIImage] = [:]
   
    // Asynchronously loads all required maneuevr icons.
    func loadManeuverIcons() {
        // Currently, the HERE SDK supports 48 maneuver actions.
        maneuverIconFileNames[.depart] = "depart.svg"
        maneuverIconFileNames[.arrive] = "arrive.svg"
        maneuverIconFileNames[.leftUTurn] = "left-u-turn.svg"
        maneuverIconFileNames[.sharpLeftTurn] = "sharp-left-turn.svg"
        maneuverIconFileNames[.leftTurn] = "left-turn.svg"
        maneuverIconFileNames[.slightLeftTurn] = "slight-left-turn.svg"
        maneuverIconFileNames[.continueOn] = "continue-on.svg"
        maneuverIconFileNames[.slightRightTurn] = "slight-right-turn.svg"
        maneuverIconFileNames[.rightTurn] = "right-turn.svg"
        maneuverIconFileNames[.sharpRightTurn] = "sharp-right-turn.svg"
        maneuverIconFileNames[.rightUTurn] = "right-u-turn.svg"
        maneuverIconFileNames[.leftExit] = "left_exit.svg"
        maneuverIconFileNames[.rightExit] = "right-exit.svg"
        maneuverIconFileNames[.leftRamp] = "left-ramp.svg"
        maneuverIconFileNames[.rightRamp] = "right-ramp.svg"
        maneuverIconFileNames[.leftFork] = "left-fork.svg"
        maneuverIconFileNames[.middleFork] = "middle-fork.svg"
        maneuverIconFileNames[.rightFork] = "right-fork.svg"
        maneuverIconFileNames[.enterHighwayFromLeft] = "enter-highway-right.svg"
        maneuverIconFileNames[.enterHighwayFromRight] = "enter-highway-left.svg"
        maneuverIconFileNames[.leftRoundaboutEnter] = "left-roundabout-enter.svg"
        maneuverIconFileNames[.rightRoundaboutEnter] = "right-roundabout-enter.svg"

        // Currently, no SVG assets are available for leftRoundaboutPass, so we use a fallback icon.
        maneuverIconFileNames[.leftRoundaboutPass] = "left-roundabout-exit4.svg"
        // Currently, no SVG assets are available for rightRoundaboutPass, so we use a fallback icon.
        maneuverIconFileNames[.rightRoundaboutPass] = "right-roundabout-exit4.svg"

        maneuverIconFileNames[.leftRoundaboutExit1] = "left-roundabout-exit1.svg"
        maneuverIconFileNames[.leftRoundaboutExit2] = "left-roundabout-exit2.svg"
        maneuverIconFileNames[.leftRoundaboutExit3] = "left-roundabout-exit3.svg"
        maneuverIconFileNames[.leftRoundaboutExit4] = "left-roundabout-exit4.svg"
        maneuverIconFileNames[.leftRoundaboutExit5] = "left-roundabout-exit5.svg"
        maneuverIconFileNames[.leftRoundaboutExit6] = "left-roundabout-exit6.svg"
        maneuverIconFileNames[.leftRoundaboutExit7] = "left-roundabout-exit7.svg"

        // Currently, no SVG assets are available for left-roundabout-exit8..12, so we use a fallback icon.
        maneuverIconFileNames[.leftRoundaboutExit8] = "left-roundabout-exit7.svg"
        maneuverIconFileNames[.leftRoundaboutExit9] = "left-roundabout-exit7.svg"
        maneuverIconFileNames[.leftRoundaboutExit10] = "left-roundabout-exit7.svg"
        maneuverIconFileNames[.leftRoundaboutExit11] = "left-roundabout-exit7.svg"
        maneuverIconFileNames[.leftRoundaboutExit12] = "left-roundabout-exit7.svg"

        maneuverIconFileNames[.rightRoundaboutExit1] = "right-roundabout-exit1.svg"
        maneuverIconFileNames[.rightRoundaboutExit2] = "right-roundabout-exit2.svg"
        maneuverIconFileNames[.rightRoundaboutExit3] = "right-roundabout-exit3.svg"
        maneuverIconFileNames[.rightRoundaboutExit4] = "right-roundabout-exit4.svg"
        maneuverIconFileNames[.rightRoundaboutExit5] = "right-roundabout-exit5.svg"
        maneuverIconFileNames[.rightRoundaboutExit6] = "right-roundabout-exit6.svg"
        maneuverIconFileNames[.rightRoundaboutExit7] = "right-roundabout-exit7.svg"

        // Currently, no SVG assets are available for right-roundabout-exit8..12, so we use a fallback icon.
        maneuverIconFileNames[.rightRoundaboutExit8] = "right-roundabout-exit7.svg"
        maneuverIconFileNames[.rightRoundaboutExit9] = "right-roundabout-exit7.svg"
        maneuverIconFileNames[.rightRoundaboutExit10] = "right-roundabout-exit7.svg"
        maneuverIconFileNames[.rightRoundaboutExit11] = "right-roundabout-exit7.svg"
        maneuverIconFileNames[.rightRoundaboutExit12] = "right-roundabout-exit7.svg"
        
        // Create a concurrent queue for executing code in the background.
        let backgroundQueue = DispatchQueue(label: "com.example.backgroundQueue", attributes: .concurrent)

        // Execute creating the images on a non-UI thread using GCD.
        backgroundQueue.async { [self] in
            for (action, fileName) in self.maneuverIconFileNames {
                if let image = UIImage(named: fileName) {
                    maneuverIcons[action] = image
                } else {
                    print("Failed to find image: \(fileName)")
                }
            }
        }
    }
    
    // Returns nil when the image was not found.
    func getManeuverIconForAction(_ action: ManeuverAction) -> UIImage? {
        return maneuverIcons[action]
    }
}
