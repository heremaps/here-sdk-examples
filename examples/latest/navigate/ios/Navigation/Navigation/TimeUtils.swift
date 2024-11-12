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

import Foundation
import heresdk

class TimeUtils{
    /**
     * Converts time in seconds to a formatted string in "HH:mm" format.
     *
     * - Parameter sec: The time in seconds to be converted.
     * - Returns: A string representing the time in "HH:mm" format.
     */
     func formatTime(sec: Double) -> String {
        let hours: Double = sec / 3600
        let minutes: Double = (sec.truncatingRemainder(dividingBy: 3600)) / 60
        
        return "\(Int32(hours)):\(Int32(minutes))"
    }
    
    /**
     * Converts length in meters to a formatted string in "km" format.
     *
     * - Parameter meters: The length in meters to be converted.
     * - Returns: A string representing the length in "km" format.
     */
     func formatLength(meters: Int32) -> String {
        let kilometers: Int32 = meters / 1000
        let remainingMeters: Int32 = meters % 1000
        
        return "\(kilometers).\(remainingMeters) km"
    }
}
