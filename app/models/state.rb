class State < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true

  # Return the state whose polygon contains the given [longitude, latitude] point.
  def self.containing(longitude, latitude)
    find_by_sql([
      "SELECT * FROM states WHERE Contains(geometry, SetSRID(MakePoint(?, ?), 4326)) LIMIT 1",
      longitude.to_f,
      latitude.to_f
    ]).first
  end

  # Serialize this state's geometry as a GeoJSON string (returns nil if no geometry).
  def geometry_geojson
    return nil if geometry.nil?

    self.class.connection.select_value(
      "SELECT AsGeoJSON(geometry) FROM states WHERE id = #{id}"
    )
  end

  # Return the centroid of this state as a [longitude, latitude] pair.
  def centroid
    row = self.class.connection.select_one(
      "SELECT X(Centroid(geometry)) AS lng, Y(Centroid(geometry)) AS lat FROM states WHERE id = #{id}"
    )
    return nil if row.nil? || row["lng"].nil?

    [row["lng"].to_f, row["lat"].to_f]
  end

  # Compute the geodesic distance (in meters) between the given point and this
  # state's centroid. Returns nil if either geometry is missing.
  def distance_to_centroid(longitude, latitude)
    sql = self.class.sanitize_sql_array([
      "SELECT Distance(Centroid(geometry), SetSRID(MakePoint(?, ?), 4326), 1) FROM states WHERE id = ?",
      longitude.to_f,
      latitude.to_f,
      id
    ])
    result = self.class.connection.select_value(sql)
    result&.to_f
  end

  # GeoJSON Feature for this state.
  def to_geojson
    geojson_str = geometry_geojson
    return nil if geojson_str.nil?

    {
      type: "Feature",
      geometry: JSON.parse(geojson_str),
      properties: {
        code: code,
        name: name
      }
    }
  end

  # GeoJSON Point Feature for this state's centroid.
  def to_centroid_geojson
    c = centroid
    return nil if c.nil?

    {
      type: "Feature",
      geometry: {type: "Point", coordinates: c},
      properties: {code: code, name: name}
    }
  end

  # GeoJSON FeatureCollection for all states that have a geometry.
  def self.to_feature_collection
    {
      type: "FeatureCollection",
      features: all.filter_map(&:to_geojson)
    }
  end

  # GeoJSON FeatureCollection of centroid points for all states.
  def self.to_centroids_feature_collection
    {
      type: "FeatureCollection",
      features: all.filter_map(&:to_centroid_geojson)
    }
  end
end
