require "test_helper"

class StateTest < ActiveSupport::TestCase
  test "centroid returns centroid within the polygon" do
    state = State.create!(code: "S1", name: "State",
      geometry_json: {type: "Polygon", coordinates: [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]}.to_json)

    assert_equal([0.5, 0.5], state.centroid)
  end
end
