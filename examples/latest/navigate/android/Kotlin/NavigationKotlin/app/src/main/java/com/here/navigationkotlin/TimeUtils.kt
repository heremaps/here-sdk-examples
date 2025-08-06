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

package com.here.navigationkotlin

import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class TimeUtils {
    /**
     * Converts time in seconds to a formatted string in "HH:mm" format.
     *
     * @param sec the time in seconds to be converted.
     * @return a string representing the time in "HH:mm" format.
     */
    fun formatTime(sec: Long): String {
        // Calculate the number of hours from the given seconds
        val hours = (sec / 3600).toInt()

        // Calculate the number of minutes remaining after extracting hours
        val minutes = ((sec % 3600) / 60).toInt()

        // Format the hours and minutes into a string with "HH:mm" format
        return String.format(Locale.getDefault(), "%02d:%02d", hours, minutes)
    }

    /**
     * Converts length in meters to a formatted string in "km" format.
     *
     * @param meters the length in meters to be converted.
     * @return a string representing the length in "km" format.
     */
    fun formatLength(meters: Int): String {
        // Calculate the number of kilometers from the given meters
        val kilometers = meters / 1000

        // Calculate the remaining meters after extracting kilometers
        val remainingMeters = meters % 1000

        // Format the kilometers and remaining meters into a string with "km" format
        return String.format(Locale.getDefault(), "%02d.%02d km", kilometers, remainingMeters)
    }

    /**
     * Returns the ETA (as a string in ‘HH:mm’ format) in the current device’s timezone, derived from the estimatedTravelTimeInSeconds, which is sourced from the Route object.
     *
     * @param remainingDuration remaining duration of trip in seconds.
     * @return A string representing the ETA in "HH:mm" format.
     */
    fun getETAinDeviceTimeZone(remainingDuration: Int): String {
        // Get an instance of the Calendar class initialized with the current date and time

        val calendar = Calendar.getInstance()

        // Set the calendar's time to the current date and time
        calendar.time = Date()

        // Add the estimated travel time (in seconds) to the current time
        calendar.add(Calendar.SECOND, remainingDuration)

        return getFormattedDate(calendar.time)
    }

    /**
     * Formats the given date to a string representation using the device's default timezone.
     *
     * @param date The Date object to be formatted.
     * @return     A string representing the formatted time in the default timezone.
     */
    private fun getFormattedDate(date: Date): String {
        // Create a DateFormat instance that formats the time in a short format (e.g., "HH:mm a").
        val dateFormat = SimpleDateFormat.getTimeInstance(DateFormat.SHORT)

        // Format the date using the configured DateFormat and return the result as a string.
        return dateFormat.format(date)
    }
}