class State < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: true

  attr_accessor :geometry_json

  after_save :update_geometry

  def centroid
    self.class
      .where(id:)
      .pick(Arel.sql("X(Centroid(geometry))"), Arel.sql("Y(Centroid(geometry))"))
      .map(&:to_f)
  end

  def to_geojson
    geojson_str = self.class.connection.select_value("SELECT AsGeoJSON(geometry) FROM states WHERE id = #{id}")

    {type: "Feature", geometry: JSON.parse(geojson_str), properties: {code: code, name: name}}
  end

  def self.to_feature_collection
    {
      type: "FeatureCollection",
      features: all.map(&:to_geojson)
    }
  end

  def to_centroid_geojson
    {
      type: "Feature",
      geometry: {type: "Point", coordinates: centroid},
      properties: {code: code, name: name}
    }
  end

  def self.to_centroids_feature_collection
    {
      type: "FeatureCollection",
      features: all.filter_map(&:to_centroid_geojson)
    }
  end

  private

  def update_geometry
    self.class.connection.execute(
      self.class.sanitize_sql_array([
        "UPDATE states SET geometry = SetSRID(GeomFromGeoJSON(?), 4326) WHERE id = ?",
        geometry_json, id
      ])
    )
  end
end
