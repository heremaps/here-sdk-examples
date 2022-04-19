/*
 * Copyright (C) 2019-2022 HERE Europe B.V.
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

// A data class meant to be used for the creation of GeoOrientationKeyframe instances that hold
// a GeoOrientation and the animation duration to reach the GeoOrientation.
class OrientationKeyframeModel {
    var geoOrientation: GeoOrientation
    var duration: TimeInterval
    
    init(geoOrientation: GeoOrientation, duration: TimeInterval) {
        self.geoOrientation = geoOrientation
        self.duration = duration
    }
}
