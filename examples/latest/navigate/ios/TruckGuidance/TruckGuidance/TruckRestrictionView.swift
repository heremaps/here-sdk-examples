/*
 * Copyright (C) 2019-2023 HERE Europe B.V.
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

// A simple view to show the next TruckRestrictionWarning event.
class TruckRestrictionView: UIView {
    
    // The dimensions of the rectangle that holds all content.
    // (xy set by the hosting view.)
    var x: CGFloat = 0
    var y: CGFloat = 0
    let w: CGFloat = 180
    let h: CGFloat = 60
    
    func onTruckRestrictionWarning(description: String) {
        // Not implemented yet.
    }
}
