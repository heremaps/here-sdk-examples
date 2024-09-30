import 'package:intl/intl.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/routing.dart';

class TimeUtils {
  /// Converts time in seconds to a formatted string in "HH:mm" format.
  ///
  /// @param sec the time in seconds to be converted.
  /// @return a string representing the time in "HH:mm" format.
  String formatTime(int sec) {
    // Calculate the number of hours from the given seconds
    int hours = sec ~/ 3600;

    // Calculate the number of minutes remaining after extracting hours
    int minutes = (sec % 3600) ~/ 60;

    // Format the hours and minutes into a string with "HH:mm" format
    return '$hours:$minutes min';
  }

  /// Converts length in meters to a formatted string in "km" format.
  ///
  /// @param meters the length in meters to be converted.
  /// @return a string representing the length in "km" format.
  String formatLength(int meters) {
    // Calculate the number of kilometers from the given meters
    int kilometers = meters ~/ 1000;

    // Calculate the remaining meters after extracting kilometers
    int remainingMeters = meters % 1000;

    // Format the kilometers and remaining meters into a string with "km" format
    return '$kilometers.$remainingMeters km';
  }

  /// Returns the ETA (as a string in ‘HH:mm’ format) in the current device’s timezone,
  /// derived from the estimatedTravelTimeInSeconds, which is sourced from the Route object.
  ///
  /// @param route Original route object from RoutingEngine.
  /// @return A string representing the ETA in "HH:mm" format.
  String getETAinDeviceTimeZone(Route route) {
    int estimatedTravelTimeInSeconds = route.duration.inSeconds;

    // Get the current date and time
    DateTime now = DateTime.now();

    // Add the estimated travel time (in seconds) to the current time
    DateTime eta = now.add(Duration(seconds: estimatedTravelTimeInSeconds));

    return DateFormat('hh:mm a').format(eta);
  }

  /// Calculates the estimated time of arrival (ETA) in the destination timezone for a given route.
  /// It is possible that the destination can be in a different timezone compared to the source.
  /// Therefore, we are also calculating the ETA in the destination timezone.
  ///
  /// @param route Original route object from RoutingEngine.
  /// @return A string representing the estimated time of arrival in the destination timezone, formatted as "HH:mm".
  String getETAinDestinationTimeZone(Route route) {
    DateTime destinationDate = getArrivalLocationTime(route).localTime;
    return DateFormat('hh:mm a').format(destinationDate);
  }

  /// Calculates the estimated time of arrival (ETA) in Coordinated Universal Time (UTC) for a given route.
  /// UTC (Coordinated Universal Time) is the primary time standard by which the world regulates clocks and time.
  ///
  /// @param route Original route object from RoutingEngine.
  /// @return A string representing the estimated time of arrival in UTC, formatted as "HH:mm".
  String getEstimatedTimeOfArrivalInUTC(Route route) {
    DateTime utcDate = getArrivalLocationTime(route).utcTime;

    // The UTC offset represents the difference in hours and minutes between a specific time zone and Coordinated Universal Time (UTC).
    // It indicates whether the local time is ahead (+) or behind (-) UTC.
    return DateFormat('hh:mm a').format(utcDate);
  }

  /// Returns the arrival time at the final location of the route.
  LocationTime getArrivalLocationTime(Route route) {
    int lastSectionIndex = route.sections.length - 1;

    // The lastSection contains cumulative duration values that increase sequentially.
    Section lastSection = route.sections[lastSectionIndex];
    return lastSection.arrivalLocationTime!;
  }
}
