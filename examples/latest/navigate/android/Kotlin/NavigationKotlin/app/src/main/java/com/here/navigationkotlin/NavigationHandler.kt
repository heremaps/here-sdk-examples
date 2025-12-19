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

package com.here.navigationkotlin

import android.content.Context
import android.util.Log
import com.here.navigation.ElectronicHorizonHandler
import com.here.sdk.core.LanguageCode
import com.here.sdk.core.UnitSystem
import com.here.sdk.core.errors.InstantiationErrorException
import com.here.sdk.navigation.EventText
import com.here.sdk.navigation.EventTextListener
import com.here.sdk.navigation.ManeuverNotificationOptions
import com.here.sdk.navigation.MapMatchedLocation
import com.here.sdk.navigation.NavigableLocation
import com.here.sdk.navigation.NavigableLocationListener
import com.here.sdk.navigation.RouteProgress
import com.here.sdk.navigation.RouteProgressListener
import com.here.sdk.navigation.TextNotificationType
import com.here.sdk.navigation.VisualNavigator
import com.here.sdk.routing.CalculateTrafficOnRouteCallback
import com.here.sdk.routing.Maneuver
import com.here.sdk.routing.ManeuverAction
import com.here.sdk.routing.Route
import com.here.sdk.routing.RoutingEngine
import com.here.sdk.routing.RoutingError
import com.here.sdk.routing.Section
import com.here.sdk.routing.Span
import com.here.sdk.routing.StreetAttributes
import com.here.sdk.routing.TrafficOnRoute
import com.here.sdk.trafficawarenavigation.DynamicRoutingEngine
import java.util.Locale

// This class combines the various events that can be emitted during turn-by-turn navigation.
// Note that this class does not show an exhaustive list of all possible events.
class NavigationHandler(
    private val context: Context?,
    private val messageView: MessageViewUpdater
) {
    enum class RoadType {
        HIGHWAY, RURAL, URBAN
    }

    private var previousManeuverIndex = -1
    private var lastMapMatchedLocation: MapMatchedLocation? = null

    private val timeUtils = TimeUtils()
    private val routingEngine: RoutingEngine
    private var lastTrafficUpdateInMilliseconds = 0L
    private lateinit var voiceAssistant: VoiceAssistant

    init {
        try {
            routingEngine = RoutingEngine()
        } catch (e: InstantiationErrorException) {
            throw RuntimeException("Initialization of RoutingEngine failed: " + e.error.name)
        }
    }

    fun setupListeners(
        visualNavigator: VisualNavigator,
        dynamicRoutingEngine: DynamicRoutingEngine,
        electronicHorizonHandler: ElectronicHorizonHandler
    ) {
        // A helper class for TTS.
        voiceAssistant = VoiceAssistant(context, object : VoiceAssistant.VoiceAssistantListener {
            override fun onInitialized() {
                setupVoiceGuidance(visualNavigator)
            }
        })

        // Notifies on the progress along the route including maneuver instructions.
        visualNavigator.routeProgressListener =
            RouteProgressListener { routeProgress: RouteProgress ->
                // Contains the progress for the next maneuver ahead and the next-next maneuvers, if any.
                val nextManeuverList = routeProgress.maneuverProgress

                val nextManeuverProgress = nextManeuverList[0]
                if (nextManeuverProgress == null) {
                    Log.d(TAG, "No next maneuver available.")
                    return@RouteProgressListener
                }

                val nextManeuverIndex = nextManeuverProgress.maneuverIndex
                val nextManeuver = visualNavigator.getManeuver(nextManeuverIndex)
                    ?: // Should never happen as we retrieved the next maneuver progress above.
                    return@RouteProgressListener

                val action = nextManeuver.action
                val roadName = getRoadName(nextManeuver, visualNavigator.route)
                val logMessage = action.name + " on " + roadName + " in " + nextManeuverProgress.remainingDistanceInMeters + " meters."

                // Angle is null for some maneuvers like Depart, Arrive and Roundabout.
                val turnAngle = nextManeuver.turnAngleInDegrees
                if (turnAngle != null) {
                    if (turnAngle > 10) {
                        Log.d(TAG, "At the next maneuver: Make a right turn of $turnAngle degrees.")
                    } else if (turnAngle < -10) {
                        Log.d(TAG, "At the next maneuver: Make a left turn of $turnAngle degrees.")
                    } else {
                        Log.d(TAG, "At the next maneuver: Go straight.")
                    }
                }

                // Angle is null when the roundabout maneuver is not an enter, exit or keep maneuver.
                val roundaboutAngle = nextManeuver.roundaboutAngleInDegrees
                if (roundaboutAngle != null) {
                    // Note that the value is negative only for left-driving countries such as UK.
                    Log.d(TAG, "At the next maneuver: Follow the roundabout for " + roundaboutAngle + " degrees to reach the exit."
                    )
                }

                var currentETAString = getETA(routeProgress)

                currentETAString = if (previousManeuverIndex != nextManeuverIndex) {
                    "$currentETAString\nNew maneuver: $logMessage"
                } else {
                    // A maneuver update contains a different distance to reach the next maneuver.
                    "$currentETAString\nManeuver update: $logMessage"
                }
                messageView.updateText(currentETAString)

                previousManeuverIndex = nextManeuverIndex

                if (lastMapMatchedLocation != null) {
                    // Update the route based on the current location of the driver.
                    // We periodically want to search for better traffic-optimized routes.
                    dynamicRoutingEngine.updateCurrentLocation(
                        lastMapMatchedLocation!!,
                        routeProgress.routeMatchedLocation.sectionIndex
                    )

                    // Update the ElectronicHorizon with the last map-matched location.
                    electronicHorizonHandler.update(lastMapMatchedLocation!!)
                }
                updateTrafficOnRoute(routeProgress, visualNavigator)
            }

        // Notifies on the current map-matched location and other useful information while driving or walking.
        visualNavigator.navigableLocationListener =
            NavigableLocationListener { currentNavigableLocation: NavigableLocation ->
                lastMapMatchedLocation = currentNavigableLocation.mapMatchedLocation
                if (lastMapMatchedLocation == null) {
                    Log.d(TAG, "The currentNavigableLocation could not be map-matched. Are you off-road?")
                    return@NavigableLocationListener
                }

                if (lastMapMatchedLocation!!.isDrivingInTheWrongWay) {
                    // For two-way streets, this value is always false. This feature is supported in tracking mode and when deviating from a route.
                    Log.d(
                        TAG,
                        "This is a one way road. User is driving against the allowed traffic direction."
                    )
                }

                val speed = currentNavigableLocation.originalLocation.speedInMetersPerSecond
                val accuracy =
                    currentNavigableLocation.originalLocation.speedAccuracyInMetersPerSecond
                Log.d(
                    TAG,
                    "Driving speed (m/s): " + speed + "plus/minus an accuracy of: " + accuracy
                )
            }

        // Notifies on messages that can be fed into TTS engines to guide the user with audible instructions.
        // The texts can be maneuver instructions or warn on certain obstacles, such as speed cameras.
        visualNavigator.eventTextListener =
            EventTextListener { eventText: EventText ->
                // We use the built-in TTS engine to synthesize the localized text as audio.
                voiceAssistant.speak(eventText.text)
                // We can optionally retrieve the associated maneuver. The details will be null if the text contains
                // non-maneuver related information, such as for speed camera warnings.
                if (eventText.type == TextNotificationType.MANEUVER && eventText.maneuverNotificationDetails != null) {
                    val maneuver = eventText.maneuverNotificationDetails!!.maneuver
                }
            }
    }

    private fun getETA(routeProgress: RouteProgress): String {
        val sectionProgressList = routeProgress.sectionProgress
        // sectionProgressList is guaranteed to be non-empty.
        val lastSectionProgress = sectionProgressList[sectionProgressList.size - 1]
        val currentETAString = "ETA: " + timeUtils.getETAinDeviceTimeZone(
            lastSectionProgress.remainingDuration.toSeconds().toInt()
        )
        Log.d(
            TAG,
            "Distance to destination in meters: " + lastSectionProgress.remainingDistanceInMeters
        )
        Log.d(TAG, "Traffic delay ahead in seconds: " + lastSectionProgress.trafficDelay.seconds)
        // Logs current ETA.
        Log.d(TAG, currentETAString)
        return currentETAString
    }

    private fun setupVoiceGuidance(visualNavigator: VisualNavigator) {
        val ttsLanguageCode =
            getLanguageCodeForDevice(VisualNavigator.getAvailableLanguagesForManeuverNotifications())
        val maneuverNotificationOptions = ManeuverNotificationOptions()
        // Set the language in which the notifications will be generated.
        maneuverNotificationOptions.language = ttsLanguageCode
        // Set the measurement system used for distances.
        maneuverNotificationOptions.unitSystem = UnitSystem.METRIC
        visualNavigator.maneuverNotificationOptions = maneuverNotificationOptions
        Log.d(
            TAG,
            "LanguageCode for maneuver notifications: $ttsLanguageCode"
        )

        // Set language to our TextToSpeech engine.
        val locale = LanguageCodeConverter.getLocale(ttsLanguageCode)
        if (voiceAssistant.setLanguage(locale)) {
            Log.d(
                TAG,
                "TextToSpeech engine uses this language: $locale"
            )
        } else {
            Log.e(
                TAG,
                "TextToSpeech engine does not support this language: $locale"
            )
        }
    }

    // Get the language preferably used on this device.
    private fun getLanguageCodeForDevice(supportedVoiceSkins: List<LanguageCode>): LanguageCode {
        // 1. Determine if preferred device language is supported by our TextToSpeech engine.

        var localeForCurrenDevice = Locale.getDefault()
        if (!voiceAssistant.isLanguageAvailable(localeForCurrenDevice)) {
            Log.e(
                TAG,
                "TextToSpeech engine does not support: $localeForCurrenDevice, falling back to EN_US."
            )
            localeForCurrenDevice = Locale("en", "US")
        }

        // 2. Determine supported voice skins from HERE SDK.
        var languageCodeForCurrenDevice =
            LanguageCodeConverter.getLanguageCode(localeForCurrenDevice)
        if (!supportedVoiceSkins.contains(languageCodeForCurrenDevice)) {
            Log.e(
                TAG,
                "No voice skins available for $languageCodeForCurrenDevice, falling back to EN_US."
            )
            languageCodeForCurrenDevice = LanguageCode.EN_US
        }

        return languageCodeForCurrenDevice
    }

    private fun getRoadName(maneuver: Maneuver, route: Route?): String {
        val currentRoadTexts = maneuver.roadTexts
        val nextRoadTexts = maneuver.nextRoadTexts

        val currentRoadName = currentRoadTexts.names.defaultValue
        val currentRoadNumber = currentRoadTexts.numbersWithDirection.defaultValue
        val nextRoadName = nextRoadTexts.names.defaultValue
        val nextRoadNumber = nextRoadTexts.numbersWithDirection.defaultValue

        var roadName = nextRoadName ?: nextRoadNumber

        route?.let {
            // On highways, we want to show the highway number instead of a possible road name,
            // while for inner city and urban areas road names are preferred over road numbers.
            if (getRoadType(maneuver, route) == RoadType.HIGHWAY) {
                roadName = nextRoadNumber ?: nextRoadName
            }
        }

        if (maneuver.action == ManeuverAction.ARRIVE) {
            // We are approaching the destination, so there's no next road.
            roadName = currentRoadName ?: currentRoadNumber
        }

        if (roadName == null) {
            // Happens only in rare cases, when also the fallback is null.
            roadName = "unnamed road"
        }

        return roadName
    }

    // Determines the road type for a given maneuver based on street attributes.
    // Return The road type classification (HIGHWAY, URBAN, RURAL, or UNDEFINED).
    private fun getRoadType(maneuver: Maneuver, route: Route): RoadType {
        val sectionOfManeuver: Section = route.sections[maneuver.sectionIndex]
        val spansInSection: List<Span?> = sectionOfManeuver.spans

        // If attributes list is empty then the road type is rural.
        if (spansInSection.isEmpty()) {
            return RoadType.RURAL
        }

        val currentSpan: Span? = spansInSection[maneuver.spanIndex]
        val streetAttributes: List<StreetAttributes>? = currentSpan?.streetAttributes

        // If attributes are not accessible then defaulting to rural road type.
        if (currentSpan == null || streetAttributes == null) {
            return RoadType.RURAL
        }

        // If attributes list contains either CONTROLLED_ACCESS_HIGHWAY, or MOTORWAY or RAMP then the road type is highway.
        // Check for highway attributes.
        if (streetAttributes.contains(StreetAttributes.CONTROLLED_ACCESS_HIGHWAY)
            || streetAttributes.contains(StreetAttributes.MOTORWAY)
            || streetAttributes.contains(StreetAttributes.RAMP)
        ) {
            return RoadType.HIGHWAY
        }

        // If attributes list contains BUILT_UP_AREA then the road type is urban.
        // Check for urban attributes.
        if (streetAttributes.contains(StreetAttributes.BUILT_UP_AREA)) {
            return RoadType.URBAN
        }

        // If the road type is neither urban nor highway, default to rural for all other cases.
        return RoadType.RURAL
    }

    // Periodically updates the traffic information for the current route.
    // This method checks whether the last traffic update occurred within the specified interval and skips the update if not.
    // Then it calculates the current traffic conditions along the route using the `RoutingEngine`.
    // Lastly, it updates the `VisualNavigator` with the newly calculated `TrafficOnRoute` object,
    // which affects the `RouteProgress` duration without altering the route geometry or distance.
    //
    // Note: This code initiates periodic calls to the HERE Routing backend. Depending on your contract,
    // each call may be charged separately. It is the application's responsibility to decide how and how
    // often this code should be executed.
    private fun updateTrafficOnRoute(
        routeProgress: RouteProgress,
        visualNavigator: VisualNavigator
    ) {
        val currentRoute = visualNavigator.route
            ?: // Should never happen.
            return

        // Below, we use 10 minutes. A common range is between 5 and 15 minutes.
        val trafficUpdateIntervalInMilliseconds = (10 * 60000).toLong() // 10 minutes.
        val now = System.currentTimeMillis()
        if ((now - lastTrafficUpdateInMilliseconds) < trafficUpdateIntervalInMilliseconds) {
            return
        }
        // Store the current time when we update trafficOnRoute.
        lastTrafficUpdateInMilliseconds = now

        val sectionProgressList = routeProgress.sectionProgress
        val lastSectionProgress = sectionProgressList[sectionProgressList.size - 1]
        val traveledDistanceOnLastSectionInMeters =
            currentRoute.lengthInMeters - lastSectionProgress.remainingDistanceInMeters
        val lastTraveledSectionIndex = routeProgress.routeMatchedLocation.sectionIndex

        routingEngine.calculateTrafficOnRoute(
            currentRoute,
            lastTraveledSectionIndex,
            traveledDistanceOnLastSectionInMeters,
            CalculateTrafficOnRouteCallback { routingError: RoutingError?, trafficOnRoute: TrafficOnRoute? ->
                if (routingError != null) {
                    Log.d(TAG, "CalculateTrafficOnRoute error: " + routingError.name)
                    return@CalculateTrafficOnRouteCallback
                }
                // Sets traffic data for the current route, affecting RouteProgress duration in SectionProgress,
                // while preserving route distance and geometry.
                visualNavigator.trafficOnRoute = trafficOnRoute
                Log.d(TAG, "Updated traffic on route.")
            })
    }

    companion object {
        private val TAG: String = NavigationHandler::class.java.name
    }
}
