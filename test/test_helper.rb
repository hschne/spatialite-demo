ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require "active_record/spatialite"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Re-initialize SpatiaLite spatial metadata for each parallel test worker's
    # database after Rails resets it. Without this, geodesic Distance(..., 1)
    # returns NULL because spatial_ref_sys is empty.
    parallelize_setup do |_worker|
      ActiveRecord::Spatialite.init
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
