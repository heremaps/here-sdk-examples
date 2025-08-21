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

import Foundation
import heresdk

class TimeUtils {
    
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
    
    /**
     * Returns the ETA (as a string in ‘HH:mm’ format) in the current device’s timezone, derived from the estimatedTravelTimeInSeconds, which is sourced from the Route object.
     *
     * - Parameter route: Original route object from RoutingEngine.
     * - Returns: A string representing the ETA in "HH:mm" format.
     */
     func getETAinDeviceTimeZone(route: Route) -> String {
        let estimatedTravelTimeInSeconds = route.duration

        // Get an instance of the Calendar class initialized with the current date and time
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.second = Int(estimatedTravelTimeInSeconds)

        // Add the estimated travel time (in seconds) to the current time
        if let etaDate = calendar.date(byAdding: dateComponents, to: Date()) {
            return getFormattedDate(etaDate)
        } else {
            return ""
        }
    }
    
    /**
     * Calculates the estimated time of arrival (ETA) in the destination timezone for a given route.
     * It is possible that the destination can be in a different timezone compared to the source.
     * Therefore, we are also calculating the ETA in the destination timezone. For example, the source can be in Berlin and the destination can be in Dubai.
     *
     * - Parameter route: Original route object from RoutingEngine.
     * - Returns: A string representing the estimated time of arrival in the destination timezone, formatted as "hh:mm".
     */
    func getETAinDestinationTimeZone(route: Route) -> String {
        let arrivalLocationTime = getArrivalLocationTime(route:route)
        let destinationDate = arrivalLocationTime.localTime

        // The timeOffset represents the difference between the local time at destination and Coordinated Universal Time (UTC) in minutes.
        let timeOffset = Int(arrivalLocationTime.utcOffset/60)

        return getFormattedDate(destinationDate,timeOffset: timeOffset)
    }
    
    /**
     * Calculates the estimated time of arrival (ETA) in Coordinated Universal Time (UTC) for a given route.
     * UTC (Coordinated Universal Time) is the primary time standard by which the world regulates clocks and time.
     *
     * @param route Original route object from RoutingEngine.
     * @return A string representing the estimated time of arrival in UTC, formatted as "HH:mm".
     */
    func getEstimatedTimeOfArrivalInUTC(route: Route) -> String {
        let utcDate = getArrivalLocationTime(route: route).utcTime

        // The UTC offset represents the difference in hours and minutes between a specific time zone and Coordinated Universal Time (UTC).
        // It indicates whether the local time is ahead (+) or behind (-) UTC.
        // By using an offset of 0, we ensure that the time being represented is in Coordinated Universal Time (UTC).
        let utcTimeOffset = 0
        return getFormattedDate(utcDate, timeOffset: utcTimeOffset)
    }
    
    /**
     * Formats the given date to a string representation based on the specified timezone offset.
     *
     * - Parameters:
     *   - date: The Date object to be formatted.
     *   - offset: The UTC offset in minutes for the desired timezone.
     * - Returns: A string representing the formatted time in the specified timezone.
     */
    private func getFormattedDate(_ date: Date, timeOffset: Int) -> String {
        // Create a DateFormatter instance that formats the time in a short format (e.g., "HH:mm a").
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short

        // Retrieve the TimeZone object corresponding to the given UTC offset.
        let timeZone = TimeZone(secondsFromGMT: timeOffset)

        // Set the DateFormatter's timezone to the retrieved TimeZone.
        dateFormatter.timeZone = timeZone

        // Format the date using the configured DateFormatter and return the result as a string.
        return dateFormatter.string(from: date)
    }
    
    // Returns the arrival time at the final location of the route.
    private func getArrivalLocationTime(route: Route) -> LocationTime {
        let lastSectionIndex = route.sections.count - 1

        // The lastSection contains cumulative duration values that increase sequentially.
        // For instance, if there are two sections, each with a duration of 5 minutes, the first section will reflect a total duration of 5 minutes,
        // while the second section will show a total duration of 10 minutes.
        // This is because the total time includes the initial 5 minutes for the first section, followed by an additional 5 minutes to complete the second section, resulting in a cumulative travel time.
        let lastSection = route.sections[lastSectionIndex]
        return lastSection.arrivalLocationTime!
    }
    
    /**
     * Formats the given date to a string representation using the device's default timezone.
     *
     * - Parameter date: The Date object to be formatted.
     * - Returns: A string representing the formatted time in the default timezone.
     */
    private func getFormattedDate(_ date: Date) -> String {
        // Create a DateFormatter instance that formats the time in a short format (e.g., "HH:mm a").
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short

        // Format the date using the configured DateFormatter and return the result as a string.
        return dateFormatter.string(from: date)
    }
}
