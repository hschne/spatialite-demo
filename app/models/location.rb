class Location < ApplicationRecord
  validates :name, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true

  after_save :update_geometry

  # Return the Austrian state containing this location (or nil if none).
  def containing_state
    @containing_state ||= State.containing(longitude, latitude)
  end

  # Geodesic distance in meters from this location to its containing state's
  # centroid. Returns nil if the location is not inside any state.
  def distance_to_state_centroid
    containing_state&.distance_to_centroid(longitude, latitude)
  end

  def to_geojson(enrich: false)
    geojson_str = self.class.connection.select_value(
      "SELECT AsGeoJSON(geometry) FROM locations WHERE id = #{id}"
    )
    props = {
      name: name,
      latitude: latitude.to_f,
      longitude: longitude.to_f
    }

    if enrich
      state = containing_state
      distance = distance_to_state_centroid
      props[:state_name] = state&.name
      props[:state_code] = state&.code
      props[:distance_to_centroid] = distance&.round
    end

    {
      type: "Feature",
      geometry: JSON.parse(geojson_str),
      properties: props
    }
  end

  def self.to_feature_collection(enrich: false)
    {
      type: "FeatureCollection",
      features: all.map { |l| l.to_geojson(enrich: enrich) }
    }
  end

  private

  def update_geometry
    self.class.connection.execute(
      "UPDATE locations SET geometry = SetSRID(MakePoint(#{longitude}, #{latitude}), 4326) WHERE id = #{id}"
    )
  end
end
