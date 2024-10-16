package com.here.navigation;

import com.here.sdk.core.LocationTime;
import com.here.sdk.routing.Route;
import com.here.sdk.routing.Section;

import java.text.DateFormat;
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
     * @param remainingDuration remaining duration of trip in seconds.
     * @return A string representing the ETA in "HH:mm" format.
     */
    public String getETAinDeviceTimeZone(int remainingDuration) {

        // Get an instance of the Calendar class initialized with the current date and time
        Calendar calendar = Calendar.getInstance();

        // Set the calendar's time to the current date and time
        calendar.setTime(new Date());

        // Add the estimated travel time (in seconds) to the current time
        calendar.add(Calendar.SECOND, remainingDuration);

        return getFormattedDate(calendar.getTime());
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

}
