class Location < ApplicationRecord
  validates :name, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true

  after_save :update_geometry

  def to_geojson
    geojson_str = self.class.connection.select_value(
      "SELECT AsGeoJSON(geometry) FROM locations WHERE id = #{id}"
    )
    {
      type: "Feature",
      geometry: JSON.parse(geojson_str),
      properties: {
        name: name,
        latitude: format("%.6f", latitude),
        longitude: format("%.6f", longitude)
      }
    }
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
