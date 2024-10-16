/*
 * Copyright (C) 2022-2024 HERE Europe B.V.
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

package com.here.hikingdiary;

import android.content.Context;

import com.here.hikingdiary.positioning.HEREPositioningSimulator;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Location;
import com.here.sdk.core.LocationListener;
import com.here.sdk.navigation.GPXDocument;
import com.here.sdk.navigation.GPXOptions;
import com.here.sdk.navigation.GPXTrack;

import java.io.File;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;

// A class to manage a GPXDocument containing multiple GPX tracks.
public class GPXManager {

    public GPXDocument gpxDocument = new GPXDocument(new ArrayList<>());
    private String gpxFilePath;
    private HEREPositioningSimulator locationSimulator = new HEREPositioningSimulator();

    // Creates the manager and loads a stored GPXDocument, if any.
    // gpxDocumentFileName example: "myGPXFile.gpx"
    public GPXManager(String gpxDocumentFileName, Context context) {
        // For this example, we specify the absolute path to the internal storage
        // owned by the app.
        File file = new File(context.getFilesDir(), gpxDocumentFileName);
        gpxFilePath = file.getAbsolutePath();

        GPXDocument loadedGPXDocument = loadGPXDocument();
        if (loadedGPXDocument != null) {
            gpxDocument = loadedGPXDocument;
        }
    }

    private GPXDocument loadGPXDocument() {
        try {
            GPXDocument gpxDocument = new GPXDocument(gpxFilePath, new GPXOptions());
            return gpxDocument;
        } catch (Exception instantiationError) {
            System.out.println("It seems no GPXDocument was stored yet: " + instantiationError);
            return null;
        }
    }

    public void startGPXTrackPlayback(LocationListener locationListener, GPXTrack gpxTrack) {
        locationSimulator.startLocating(locationListener, gpxTrack);
    }

    public void stopGPXTrackPlayback() {
        locationSimulator.stopLocating();
    }

    public boolean saveGPXTrack(GPXTrack gpxTrack) {
        if (gpxTrack.getLocations().size() < 2) {
            return false;
        }

        if (gpxTrack.getName().isEmpty()) {
            gpxTrack.setName(getName());
        }

        if (gpxTrack.getDescription().isEmpty()) {
            gpxTrack.setDescription(getCurrentDate());
        }

        gpxDocument.addTrack(gpxTrack);

        return gpxDocument.save(gpxFilePath);
    }

    public GPXTrack getGPXTrack(int index) {
        if (gpxDocument.getTracks().isEmpty()) {
            return null;
        }

        if (index < 0 || index > gpxDocument.getTracks().size() - 1) {
            return null;
        }

        return gpxDocument.getTracks().get(index);
    }
    public boolean deleteGPXTrack(int index) {
        List<GPXTrack> gpxTracks = gpxDocument.getTracks();
        gpxTracks.remove(index);

        // Replace the existing document with the updated tracks list.
        gpxDocument = new GPXDocument(gpxTracks);
        return gpxDocument.save(gpxFilePath);
    }

    public List<GeoCoordinates> getGeoCoordinatesList(GPXTrack track) {
        List<Location> locations = track.getLocations();
        List<GeoCoordinates> geoCoordinatesList = new ArrayList<>();
        for (Location location : locations) {
            geoCoordinatesList.add(location.coordinates);
        }
        return geoCoordinatesList;
    }

    private String getCurrentDate() {
        Date date = new Date();
        DateFormat formatter = new SimpleDateFormat("yy/MM/dd, HH:mm");
        return formatter.format(date);
    }

    private String getName() {
        Date date = new Date();
        DateFormat formatter = new SimpleDateFormat("yyMMddHHmmss");
        return "gpxTrack" + formatter.format(date);
    }
}
