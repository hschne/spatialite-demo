namespace :db do
  # After db:create, initialize spatial metadata so a fresh database is
  # ready for spatial queries immediately.
  Rake::Task["db:create"].enhance do
    Rake::Task["spatialite:init"].invoke
  end

  namespace :test do
    # After db:test:prepare (which resets the test database), re-initialize
    # spatial metadata so tests can use geodesic Distance() etc.
    Rake::Task["db:test:prepare"].enhance do
      Rake::Task["spatialite:init_test"].invoke
    end
  end
end

namespace :spatialite do
  desc "Initialize SpatiaLite spatial metadata for the current environment database"
  task init: :environment do
    ActiveRecord::Base.establish_connection
    require "active_record/spatialite"
    ActiveRecord::Spatialite.init
    puts "SpatiaLite spatial metadata initialized."
  rescue => e
    puts "SpatiaLite init skipped: #{e.message}"
  end

  desc "Initialize SpatiaLite spatial metadata for the test database"
  task init_test: :environment do
    ActiveRecord::Base.establish_connection(:test)
    require "active_record/spatialite"
    ActiveRecord::Spatialite.init
    puts "SpatiaLite spatial metadata initialized for test database."
  rescue => e
    puts "SpatiaLite init_test skipped: #{e.message}"
  end
end
