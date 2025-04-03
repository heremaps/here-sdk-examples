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
package com.example.routing

import com.here.sdk.core.LocationTime
import com.here.sdk.routing.Route
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

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
     * @param route Original route object from RoutingEngine.
     * @return A string representing the ETA in "HH:mm" format.
     */
    fun getETAinDeviceTimeZone(route: Route): String {
        val estimatedTravelTimeInSeconds = route.duration.toSeconds()

        // Get an instance of the Calendar class initialized with the current date and time
        val calendar = Calendar.getInstance()

        // Set the calendar's time to the current date and time
        calendar.time = Date()

        // Add the estimated travel time (in seconds) to the current time
        calendar.add(Calendar.SECOND, estimatedTravelTimeInSeconds.toInt())

        return getFormattedDate(calendar.time)
    }

    /**
     * Calculates the estimated time of arrival (ETA) in the destination timezone for a given route.
     * It is possible that the destination can be in a different timezone compared to the source.
     * Therefore, we are also calculating the ETA in the destination timezone. For example, the source can be in Berlin and the destination can be in Dubai.
     *
     * @param route Original route object from RoutingEngine.
     * @return A string representing the estimated time of arrival in the destination timezone, formatted as "hh:mm".
     */
    fun getETAinDestinationTimeZone(route: Route): String {
        val arrivalLocationTime = getArrivalLocationTime(route)
        val destinationDate = arrivalLocationTime!!.localTime

        // The timeOffset represents the difference between the local time at destination and Coordinated Universal Time (UTC) in minutes.
        val timeOffset = arrivalLocationTime.utcOffset.toMinutes().toInt()

        return getFormattedDate(destinationDate, timeOffset)
    }

    /**
     * Calculates the estimated time of arrival (ETA) in Coordinated Universal Time (UTC) for a given route.
     * UTC (Coordinated Universal Time) is the primary time standard by which the world regulates clocks and time.
     *
     * @param route Original route object from RoutingEngine.
     * @return A string representing the estimated time of arrival in UTC, formatted as "HH:mm".
     */
    fun getEstimatedTimeOfArrivalInUTC(route: Route): String {
        val utcDate = getArrivalLocationTime(route)!!.utcTime

        // The UTC offset represents the difference in hours and minutes between a specific time zone and Coordinated Universal Time (UTC).
        // It indicates whether the local time is ahead (+) or behind (-) UTC.
        // By using an offset of 0, we ensure that the time being represented is in Coordinated Universal Time (UTC).
        val utcTimeOffset = 0
        return getFormattedDate(utcDate, utcTimeOffset)
    }

    /**
     * Formats the given date to a string representation based on the specified timezone offset.
     *
     * @param date   The Date object to be formatted.
     * @param offset The UTC offset in minutes for the desired timezone.
     * @return A string representing the formatted time in the specified timezone.
     */
    private fun getFormattedDate(date: Date, offset: Int): String {
        // Create a DateFormat instance that formats the time in a short format (e.g., "HH:mm a").
        val dateFormat = SimpleDateFormat.getTimeInstance(DateFormat.SHORT)

        // Retrieve the TimeZone object corresponding to the given UTC offset.
        val timeZone = getTimeZone(offset)

        // Set the DateFormat's timezone to the retrieved TimeZone.
        dateFormat.timeZone = timeZone

        // Format the date using the configured DateFormat and return the result as a string.
        return dateFormat.format(date)
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

    /**
     * Retrieves a TimeZone object based on the given UTC offset in minutes.
     *
     * @param utcOffsetInMinutes The UTC offset in minutes (can be positive or negative).
     * @return A TimeZone object representing the specified offset from GMT.
     */
    private fun getTimeZone(utcOffsetInMinutes: Int): TimeZone {
        // Calculate the offset in hours.
        val hours = utcOffsetInMinutes / 60

        // Calculate the remaining offset in minutes after converting to hours.
        val minutes = utcOffsetInMinutes % 60

        // Format the time zone as a GMT offset string, such as "GMT+05:30" or "GMT-04:00".
        val timeZoneId = "GMT%+03d:%02d".format(hours, minutes)

        // Retrieve and return the TimeZone object corresponding to the constructed GMT time zone ID.
        return TimeZone.getTimeZone(timeZoneId)
    }

    // Returns the arrival time at the final location of the route.
    private fun getArrivalLocationTime(route: Route): LocationTime? {
        val lastSectionIndex = route.sections.size - 1

        // The lastSection contains cumulative duration values that increase sequentially.
        // For instance, if there are two sections, each with a duration of 5 minutes, the first section will reflect a total duration of 5 minutes,
        // while the second section will show a total duration of 10 minutes.
        // This is because the total time includes the initial 5 minutes for the first section, followed by an additional 5 minutes to complete the second section, resulting in a cumulative travel time.
        val lastSection = route.sections[lastSectionIndex]
        return lastSection.arrivalLocationTime
    }
}
