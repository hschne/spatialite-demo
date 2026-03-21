require "test_helper"

class StateTest < ActiveSupport::TestCase
  # ── Fixtures/setup ──────────────────────────────────────────────────────────
  # We cannot store SpatiaLite geometry blobs in YAML fixtures, so we build
  # State records via raw SQL in a setup block.

  setup do
    # Wien – a rough bounding polygon centred on Vienna.
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

    # Tirol – stored as a tiny MultiPolygon to exercise that branch.
    tirol_geojson = {
      type: "MultiPolygon",
      coordinates: [
        [
          [
            [10.44, 47.27],
            [12.94, 47.27],
            [12.94, 47.52],
            [10.44, 47.52],
            [10.44, 47.27]
          ]
        ]
      ]
    }.to_json

    [
      {code: "AT9", name: "Wien", geojson: wien_geojson},
      {code: "AT7", name: "Tirol", geojson: tirol_geojson}
    ].each do |attrs|
      state = State.find_or_initialize_by(code: attrs[:code])
      state.name = attrs[:name]
      state.save!(validate: false)

      State.connection.execute(
        State.sanitize_sql_array([
          "UPDATE states SET geometry = SetSRID(GeomFromGeoJSON(?), 4326) WHERE id = ?",
          attrs[:geojson],
          state.id
        ])
      )
    end

    @wien = State.find_by!(code: "AT9")
    @tirol = State.find_by!(code: "AT7")
  end

  teardown do
    State.delete_all
  end

  # ── to_feature_collection ────────────────────────────────────────────────────

  test "to_feature_collection returns a valid GeoJSON FeatureCollection" do
    fc = State.to_feature_collection
    assert_equal "FeatureCollection", fc[:type]
    assert_equal 2, fc[:features].size

    fc[:features].each do |f|
      assert_equal "Feature", f[:type]
      assert_includes %w[Polygon MultiPolygon], f[:geometry]["type"]
      assert f[:properties][:name].present?
      assert f[:properties][:code].present?
    end
  end

  # ── containing ───────────────────────────────────────────────────────────────

  test "containing returns Wien for a point inside Wien" do
    # Vienna city center
    state = State.containing(16.3738, 48.2082)
    assert_not_nil state
    assert_equal "Wien", state.name
  end

  test "containing returns nil for a point outside all states" do
    # Somewhere in the middle of the Pacific
    state = State.containing(170.0, 10.0)
    assert_nil state
  end

  # ── distance_to_centroid ─────────────────────────────────────────────────────

  test "distance_to_centroid returns a plausible meter value for a known point" do
    # Vienna center – should be a few tens of km from Wien's centroid at most.
    distance = @wien.distance_to_centroid(16.3738, 48.2082)
    assert_not_nil distance
    assert distance > 0, "distance should be positive"
    assert distance < 100_000, "distance should be under 100 km for a point inside Wien"
  end

  # ── centroid ─────────────────────────────────────────────────────────────────

  test "centroid returns a lng/lat pair" do
    c = @wien.centroid
    assert_not_nil c
    assert_equal 2, c.size
    lng, lat = c
    # Wien centroid must be in a sane range.
    assert_in_delta 16.38, lng, 0.3
    assert_in_delta 48.22, lat, 0.3
  end

  # ── geometry_geojson ─────────────────────────────────────────────────────────

  test "geometry_geojson returns valid JSON for stored geometry" do
    json = @tirol.geometry_geojson
    assert_not_nil json
    parsed = JSON.parse(json)
    assert_equal "MultiPolygon", parsed["type"]
  end
end
