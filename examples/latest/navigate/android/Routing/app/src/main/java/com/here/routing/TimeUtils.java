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

package com.here.routing;

import com.here.sdk.core.LocationTime;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.Section;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

public class TimeUtils {

    /**
     * Converts time in seconds to a formatted string in "HH:mm" format.
     *
     * @param sec the time in seconds to be converted.
     * @return a string representing the time in "HH:mm" format.
     */
    public String formatTime(long sec) {
        // Calculate the number of hours from the given seconds
        int hours = (int) (sec / 3600);

        // Calculate the number of minutes remaining after extracting hours
        int minutes = (int) ((sec % 3600) / 60);

        // Format the hours and minutes into a string with "HH:mm" format
        return String.format(Locale.getDefault(), "%02d:%02d", hours, minutes);
    }

    /**
     * Converts length in meters to a formatted string in "km" format.
     *
     * @param meters the length in meters to be converted.
     * @return a string representing the length in "km" format.
     */
    public String formatLength(int meters) {
        // Calculate the number of kilometers from the given meters
        int kilometers = meters / 1000;

        // Calculate the remaining meters after extracting kilometers
        int remainingMeters = meters % 1000;

        // Format the kilometers and remaining meters into a string with "km" format
        return String.format(Locale.getDefault(), "%02d.%02d km", kilometers, remainingMeters);
    }

    /**
     * Returns the ETA (as a string in ‘HH:mm’ format) in the current device’s timezone, derived from the estimatedTravelTimeInSeconds, which is sourced from the Route object.
     *
     * @param route Original route object from RoutingEngine.
     * @return A string representing the ETA in "HH:mm" format.
     */
    public String getETAinDeviceTimeZone(Route route) {
        long estimatedTravelTimeInSeconds = route.getDuration().toSeconds();

        // Get an instance of the Calendar class initialized with the current date and time
        Calendar calendar = Calendar.getInstance();

        // Set the calendar's time to the current date and time
        calendar.setTime(new Date());

        // Add the estimated travel time (in seconds) to the current time
        calendar.add(Calendar.SECOND, (int) estimatedTravelTimeInSeconds);

        return getFormattedDate(calendar.getTime());
    }

    /**
     * Calculates the estimated time of arrival (ETA) in the destination timezone for a given route.
     * It is possible that the destination can be in a different timezone compared to the source.
     * Therefore, we are also calculating the ETA in the destination timezone. For example, the source can be in Berlin and the destination can be in Dubai.
     *
     * @param route Original route object from RoutingEngine.
     * @return A string representing the estimated time of arrival in the destination timezone, formatted as "hh:mm".
     */
    public String getETAinDestinationTimeZone(Route route) {
        LocationTime arrivalLocationTime = getArrivalLocationTime(route);
        Date destinationDate = arrivalLocationTime.localTime;

        // The timeOffset represents the difference between the local time at destination and Coordinated Universal Time (UTC) in minutes.
        int timeOffset = (int) arrivalLocationTime.utcOffset.toMinutes();

        return getFormattedDate(destinationDate, timeOffset);
    }

    /**
     * Calculates the estimated time of arrival (ETA) in Coordinated Universal Time (UTC) for a given route.
     * UTC (Coordinated Universal Time) is the primary time standard by which the world regulates clocks and time.
     *
     * @param route Original route object from RoutingEngine.
     * @return A string representing the estimated time of arrival in UTC, formatted as "HH:mm".
     */
    public String getEstimatedTimeOfArrivalInUTC(Route route) {
        Date utcDate = getArrivalLocationTime(route).utcTime;

        // The UTC offset represents the difference in hours and minutes between a specific time zone and Coordinated Universal Time (UTC).
        // It indicates whether the local time is ahead (+) or behind (-) UTC.
        // By using an offset of 0, we ensure that the time being represented is in Coordinated Universal Time (UTC).
        int utcTimeOffset = 0;
        return getFormattedDate(utcDate, utcTimeOffset);
    }

    /**
     * Formats the given date to a string representation based on the specified timezone offset.
     *
     * @param date   The Date object to be formatted.
     * @param offset The UTC offset in minutes for the desired timezone.
     * @return A string representing the formatted time in the specified timezone.
     */
    private String getFormattedDate(Date date, int offset) {
        // Create a DateFormat instance that formats the time in a short format (e.g., "HH:mm a").
        java.text.DateFormat dateFormat = SimpleDateFormat.getTimeInstance(java.text.DateFormat.SHORT);

        // Retrieve the TimeZone object corresponding to the given UTC offset.
        TimeZone timeZone = getTimeZone(offset);

        // Set the DateFormat's timezone to the retrieved TimeZone.
        dateFormat.setTimeZone(timeZone);

        // Format the date using the configured DateFormat and return the result as a string.
        return dateFormat.format(date);
    }

    /**
     * Formats the given date to a string representation using the device's default timezone.
     *
     * @param date The Date object to be formatted.
     * @return     A string representing the formatted time in the default timezone.
     */
    private String getFormattedDate(Date date) {
        // Create a DateFormat instance that formats the time in a short format (e.g., "HH:mm a").
        java.text.DateFormat dateFormat = SimpleDateFormat.getTimeInstance(java.text.DateFormat.SHORT);

        // Format the date using the configured DateFormat and return the result as a string.
        return dateFormat.format(date);
    }

    /**
     * Retrieves a TimeZone object based on the given UTC offset in minutes.
     *
     * @param utcOffsetInMinutes The UTC offset in minutes (can be positive or negative).
     * @return A TimeZone object representing the specified offset from GMT.
     */
    private TimeZone getTimeZone(int utcOffsetInMinutes) {
        // Calculate the offset in hours.
        int hours = utcOffsetInMinutes / 60;

        // Calculate the remaining offset in minutes after converting to hours.
        int minutes = utcOffsetInMinutes % 60;

        // Create a string representing the time zone in GMT format (e.g., "GMT+05:30").
        String timeZoneId = String.format("GMT%+03d:%02d", hours, minutes);

        // Retrieve and return the TimeZone object corresponding to the constructed GMT time zone ID.
        return TimeZone.getTimeZone(timeZoneId);
    }


    // Returns the arrival time at the final location of the route.
    private LocationTime getArrivalLocationTime(Route route) {
        int lastSectionIndex = route.getSections().size() - 1;

        // The lastSection contains cumulative duration values that increase sequentially.
        // For instance, if there are two sections, each with a duration of 5 minutes, the first section will reflect a total duration of 5 minutes,
        // while the second section will show a total duration of 10 minutes.
        // This is because the total time includes the initial 5 minutes for the first section, followed by an additional 5 minutes to complete the second section, resulting in a cumulative travel time.
        Section lastSection = route.getSections().get(lastSectionIndex);
        return lastSection.getArrivalLocationTime();
    }

}
