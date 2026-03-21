require "test_helper"

class LocationTest < ActiveSupport::TestCase
  # ── Setup ────────────────────────────────────────────────────────────────────
  # Create a Wien state polygon and a sample location in test setup.
  # Fixtures cannot store SpatiaLite geometry blobs, so we use raw SQL.

  setup do
    wien_geojson = {
      type: "Polygon",
      coordinates: [
        [
          [16.18, 48.12],
          [16.58, 48.12],
          [16.58, 48.32],
          [16.18, 48.32],
          [16.18, 48.12]
        ]
      ]
    }.to_json

    @wien = State.find_or_initialize_by(code: "AT9")
    @wien.name = "Wien"
    @wien.save!(validate: false)

    State.connection.execute(
      State.sanitize_sql_array([
        "UPDATE states SET geometry = SetSRID(GeomFromGeoJSON(?), 4326) WHERE id = ?",
        wien_geojson,
        @wien.id
      ])
    )

    # Location inside Wien (Vienna city center).
    @vienna = Location.create!(name: "Vienna Center", latitude: 48.2082, longitude: 16.3738)

    # Location outside all states (Pacific Ocean).
    @pacific = Location.create!(name: "Pacific", latitude: 10.0, longitude: 170.0)
  end

  teardown do
    Location.delete_all
    State.delete_all
  end

  # ── Point-in-polygon ─────────────────────────────────────────────────────────

  test "containing_state returns Wien for a location inside Wien" do
    state = @vienna.containing_state
    assert_not_nil state
    assert_equal "Wien", state.name
  end

  test "containing_state returns nil for a location outside all states" do
    state = @pacific.containing_state
    assert_nil state
  end

  # ── Distance to centroid ──────────────────────────────────────────────────────

  test "distance_to_state_centroid returns a plausible meter value" do
    distance = @vienna.distance_to_state_centroid
    assert_not_nil distance
    assert distance > 0
    assert distance < 100_000, "expected < 100 km for a point inside Wien"
  end

  test "distance_to_state_centroid returns nil when no containing state" do
    distance = @pacific.distance_to_state_centroid
    assert_nil distance
  end

  # ── GeoJSON serialization ────────────────────────────────────────────────────

  test "to_geojson without enrichment omits state and distance" do
    feature = @vienna.to_geojson
    assert_equal "Feature", feature[:type]
    props = feature[:properties]
    refute props.key?(:state_name)
    refute props.key?(:distance_to_centroid)
  end

  test "to_geojson with enrich: true includes state name and distance" do
    feature = @vienna.to_geojson(enrich: true)
    props = feature[:properties]
    assert_equal "Wien", props[:state_name]
    assert_not_nil props[:distance_to_centroid]
    assert props[:distance_to_centroid] > 0
  end

  test "to_geojson with enrich: true sets nil state fields for outside location" do
    feature = @pacific.to_geojson(enrich: true)
    props = feature[:properties]
    assert_nil props[:state_name]
    assert_nil props[:distance_to_centroid]
  end

  test "to_feature_collection with enrich returns FeatureCollection" do
    fc = Location.to_feature_collection(enrich: true)
    assert_equal "FeatureCollection", fc[:type]
    assert_equal 2, fc[:features].size
  end
end
