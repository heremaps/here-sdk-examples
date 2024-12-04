package com.here.sdk.custompointtilesourcewithclustering;

import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;

public class TilingUtils {

  private static final int tileSize = 256;
  private static final double earthRadius = 6378137.0;
  private static final double twoPi = 2.0 * Math.PI;
  private static final double halfPi = Math.PI * 0.5;
  private static final double toRadiansFactor = Math.PI / 180.0;
  private static final double toDegreesFactor = 180.0 / Math.PI;
  private static final double originShift = twoPi * earthRadius * 0.5;
  private static final double initialResolution =
      twoPi * earthRadius / tileSize;

  public static com.here.sdk.core.GeoBox
  getGeoBox(com.here.sdk.mapview.datasource.TileKey tileKey) {
    // TMS -> XYZ
    int tileZ = tileKey.level;
    int tileX = tileKey.x;
    int tileY = (1 << tileZ) - 1 - tileKey.y;

    int pointXWest = tileX * tileSize;
    int pointYNorth = tileY * tileSize;
    int pointXEast = (tileX + 1) * tileSize;
    int pointYSouth = (tileY + 1) * tileSize;

    // Compute corner coordinates.
    double resolutionAtCurrentZ = initialResolution / (1 << tileZ);
    double halfSize = tileSize * (1 << tileZ) * 0.5;
    // SW
    double meterXW = Math.abs(pointXWest * resolutionAtCurrentZ - originShift) *
                     (pointXWest < halfSize ? -1 : 1);

    double meterYS =
        Math.abs(pointYSouth * resolutionAtCurrentZ - originShift) *
        (pointYSouth > halfSize ? -1 : 1);

    double longitudeSW = (meterXW / originShift) * 180.0;
    double latitudeSW = (meterYS / originShift) * 180.0;
    latitudeSW =
        toDegreesFactor *
        (2 * Math.atan(Math.exp(latitudeSW * toRadiansFactor)) - halfPi);

    // NE
    double meterXE = Math.abs(pointXEast * resolutionAtCurrentZ - originShift) *
                     (pointXEast < halfSize ? -1 : 1);

    double meterYN =
        Math.abs(pointYNorth * resolutionAtCurrentZ - originShift) *
        (pointYNorth > halfSize ? -1 : 1);
    double longitudeNE = (meterXE / originShift) * 180.0;
    double latitudeNE = (meterYN / originShift) * 180.0;

    latitudeNE =
        toDegreesFactor *
        (2 * Math.atan(Math.exp(latitudeNE * toRadiansFactor)) - halfPi);

    return new GeoBox(new GeoCoordinates(latitudeSW, longitudeSW),
                      new GeoCoordinates(latitudeNE, longitudeNE));
  }
}
