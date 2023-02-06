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

import heresdk
import Foundation

// A class to manage a GPXDocument containing multiple GPX tracks.
class GPXManager {
    
    public var gpxDocument = GPXDocument(tracks: [])
    private var gpxDocumentFileName: String
    private let locationSimulator = HEREPositioningSimulator()
    
    // Creates an instance of this class and loads a GPXDocument with the given file name.
    // If no GPXDocument was found, then an empty GPXDocument is used.
    init(gpxDocumentFileName: String) {
        self.gpxDocumentFileName = gpxDocumentFileName
        gpxDocument = loadGPXDocument(gpxDocumentFileName) ?? gpxDocument
    }
    
    // Returns the stored GPXDocument or nil if no document was stored yet.
    private func loadGPXDocument(_ gpxDocumentFileName: String) -> GPXDocument? {
        do {
            let gpxDocument = try GPXDocument(gpxFilePath: getGPXDocumentFilePath(gpxDocumentFileName),
                                              options: GPXOptions())
            return gpxDocument
        } catch let instantiationError {
            print("It seems no GPXDocument was stored yet: \(instantiationError)")
            return nil
        }
    }
    
    // Starts GPXTrack playback via LocationSimulator.
    public func startGPXTrackPlayback(_ locationDelegate: LocationDelegate, _ gpxTrack: GPXTrack) {
        locationSimulator.startLocating(locationDelegate: locationDelegate, gpxTrack: gpxTrack)
    }
    
    public func stopGPXTrackPlayback() {
        locationSimulator.stopLocating()
    }
    
    // Returns true when the track was added to the GPXDocument and saved successfully, false otherwise.
    public func saveGPXTrack(_ gpxTrack: GPXTrack) -> Bool {
        if gpxTrack.getLocations().count < 2 {
            return false
        }
        
        if gpxTrack.name.isEmpty {
            gpxTrack.name = getName()
        }
        
        if gpxTrack.description.isEmpty {
            gpxTrack.description = getCurrentDate()
        }
        
        gpxDocument.addTrack(trackToAdd: gpxTrack)
        
        return gpxDocument.save(gpxFilePath: getGPXDocumentFilePath(gpxDocumentFileName))
    }
    
    // Gets an exsting track from the GPXDocument, if available at the given index.
    public func getGPXTrack(index: Int) -> GPXTrack? {
        if gpxDocument.tracks.isEmpty {
            return nil
        }
        
        if index < 0 || index > gpxDocument.tracks.count - 1 {
            return nil
        }
        
        return gpxDocument.tracks[index]
    }
    
    // Deletes an existing track from a GPXDocument, if available at the given index.
    public func deleteGPXTrack(index: Int) -> Bool {
        var gpxTracks = gpxDocument.tracks
        gpxTracks.remove(at: index)
                
        // Replace the existing document with the updated tracks list.
        gpxDocument = GPXDocument(tracks: gpxTracks)
        return gpxDocument.save(gpxFilePath: getGPXDocumentFilePath(gpxDocumentFileName))
    }
    
    public func getGeoCoordinatesList(track: GPXTrack) -> [GeoCoordinates] {
        let locations = track.getLocations()
        var geoCoordinatesList: [GeoCoordinates] = []
        for location in locations {
            geoCoordinatesList.append(location.coordinates)
        }
        return geoCoordinatesList
    }
    
    private func getGPXDocumentFilePath(_ fileName: String) -> String {
        // Finds the document directory of the user on a device.
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].path + "/" + fileName
    }
   
    private func getCurrentDate() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yy/MM/dd, HH:mm"
        return formatter.string(from: date)
    }
    
    private func getName() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMddHHmmss"
        return "gpxTrack" + formatter.string(from: date)
    }
}
