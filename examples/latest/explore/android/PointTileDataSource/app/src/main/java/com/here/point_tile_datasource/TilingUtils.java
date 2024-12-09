package com.here.point_tile_datasource;

import com.here.sdk.core.GeoBox;
import com.here.sdk.core.GeoCoordinates;
import com.here.sdk.core.Point3D;
import com.here.sdk.mapview.datasource.TileKey;

public class TilingUtils {

  private static final int tileSize = 256;
  private static final double earthRadius = 6378137.0;
  private static final double equatorialCircumference =
      2 * earthRadius * Math.PI;

  private static final double twoPi = 2.0 * Math.PI;
  private static final double halfPi = Math.PI * 0.5;
  private static final double toRadiansFactor = Math.PI / 180.0;
  private static final double toDegreesFactor = 180.0 / Math.PI;
  private static final double originShift = twoPi * earthRadius * 0.5;
  private static final double initialResolution =
      twoPi * earthRadius / tileSize;

  private static final double maxLatitude = 1.4844222297453323;
  private static final double minLatitude = -1 * maxLatitude;

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

  public static com.here.sdk.core.GeoCoordinates
  geoBoxCenter(com.here.sdk.core.GeoBox geoBox) {
    double latitude =
        (geoBox.southWestCorner.latitude + geoBox.northEastCorner.latitude) *
        0.5;

    double west = geoBox.southWestCorner.longitude;
    double east = geoBox.northEastCorner.longitude;

    if (west <= east) {
      return new com.here.sdk.core.GeoCoordinates(latitude,
                                                  (west + east) * 0.5);
    }

    double longitude = (2 * Math.PI + east + west) * 0.5;
    if (longitude > Math.PI) {
      longitude -= 2 * Math.PI;
    }

    return new com.here.sdk.core.GeoCoordinates(latitude, longitude);
  }

  // overall from TileKeyUtils::GeoCoordinatesToTileKey
  // TODO: test this stuff
  public static com.here.sdk.mapview.datasource.TileKey
  toTileKey(com.here.sdk.core.GeoCoordinates coordinates, int level) {
    Point3D worldCoordinates = toWorldCoordinates(coordinates);

    Size2I levelSize = getLevelSize(level);

    if (worldCoordinates.x < 0.0 ||
        worldCoordinates.x > equatorialCircumference ||
        worldCoordinates.y < 0.0 ||
        worldCoordinates.y > equatorialCircumference) {
      throw new RuntimeException("invalid world coordinates");
    }

    int column = Math.min(levelSize.width - 1,
                          ((int)(levelSize.width * (worldCoordinates.x - 0) /
                                 equatorialCircumference)));

    int row = Math.min(levelSize.height - 1,
                       ((int)(levelSize.height * (worldCoordinates.y - 0) /
                              equatorialCircumference)));

    return new TileKey(column, row, level);
  }

  /// from WebMercatorProjection
  ///
  private static double clamp(double value, double min, double max) {
    return Math.min(Math.max(value, min), max);
  }
  // Projects latitude to normalized coordinate.
  private static double projectLatitude(double latitude) {
    double result = Math.tan(Math.PI * 0.25 + latitude * 0.5);
    return Math.log(result) / Math.PI;
  }

  private static double clampLatitude(double latitude) {
    return clamp(latitude, minLatitude, maxLatitude);
  }

  private static double projectClampLatitude(double latitude) {
    return projectLatitude(clampLatitude(latitude));
  }

  // Geo to world coordinates (from WebMercatorProjection::toWorld)
  public static com.here.sdk.core.Point3D
  toWorldCoordinates(com.here.sdk.core.GeoCoordinates coords) {

    double longitude = coords.longitude * toRadiansFactor;
    double latitude = coords.latitude * toRadiansFactor;

    return new Point3D((longitude + Math.PI) / twoPi * equatorialCircumference,
                       (0.5 * (projectClampLatitude(latitude) + 1)) *
                           equatorialCircumference,
                       coords.altitude == null ? 0 : coords.altitude);
  }

  /// from QuadTreeSubdivisionScheme
  ///
  public static class Size2I {
    int width;
    int height;
    public Size2I(int width, int height) {
      this.width = width;
      this.height = height;
    }
  }
  public static Size2I getLevelSize(int level) {
    return new Size2I(1 << level, 1 << level);
  }
}
