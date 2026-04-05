require "test_helper"

class LocationTest < ActiveSupport::TestCase
  setup do
    State.create!(code: "S1", name: "State",
      geometry_json: {type: "Polygon", coordinates: [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]}.to_json)
  end

  test "distance_to_state_centroid returns a positive value for a point inside the state" do
    location = Location.create!(name: "Inside", latitude: 0.25, longitude: 0.75)

    distance = location.distance_to_state_centroid

    assert distance > 0
  end

  test "distance_to_state_centroid returns nil for a point outside state" do
    location = Location.create!(name: "Outside", latitude: 10.0, longitude: 10.0)

    assert_nil location.distance_to_state_centroid
  end
end
