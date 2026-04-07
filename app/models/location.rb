class Location < ApplicationRecord
  validates :name, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true

  after_save :update_geometry

  def to_geojson
    geojson_str = self.class.connection.select_value(
      "SELECT AsGeoJSON(geometry) FROM locations WHERE id = #{id}"
    )
    state = containing_state
    distance = distance_to_state_centroid

    {
      type: "Feature",
      geometry: JSON.parse(geojson_str),
      properties: {
        name: name,
        latitude: format("%.6f", latitude),
        longitude: format("%.6f", longitude),
        state_name: state&.name,
        state_code: state&.code,
        distance_to_centroid: distance&.round
      }
    }
  end

  def containing_state
    State.find_by_sql([
      <<~SQL,
        SELECT *
        FROM states
        WHERE Contains(geometry, SetSRID(MakePoint(:longitude, :latitude), 4326))
        LIMIT 1
      SQL
      {longitude: longitude.to_f, latitude: latitude.to_f}
    ]).first
  end

  def distance_to_state_centroid
    sql = self.class.sanitize_sql_array([
      <<~SQL,
        SELECT Distance(Centroid(geometry), SetSRID(MakePoint(:longitude, :latitude), 4326), 1)
        FROM states
        WHERE Contains(geometry, SetSRID(MakePoint(:longitude, :latitude), 4326))
        LIMIT 1
      SQL
      {longitude: longitude.to_f, latitude: latitude.to_f}
    ])
    self.class.connection.select_value(sql)&.to_f
  end

  def self.to_feature_collection
    {
      type: "FeatureCollection",
      features: all.map(&:to_geojson)
    }
  end

  private

  def update_geometry
    self.class.connection.execute(
      "UPDATE locations SET geometry = SetSRID(MakePoint(#{longitude}, #{latitude}), 4326) WHERE id = #{id}"
    )
  end
end
