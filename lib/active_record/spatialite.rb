module ActiveRecord
  module Spatialite
    # Initialize spatial metadata on a fresh database.
    # Calls InitSpatialMetadata(1) unless spatial_ref_sys already contains rows.
    def self.init(connection = ActiveRecord::Base.connection)
      tables = connection.select_values("SELECT name FROM sqlite_master WHERE type='table' AND name='spatial_ref_sys'")
      if tables.empty?
        connection.execute("SELECT InitSpatialMetadata(1)")
        return
      end

      count = connection.select_value("SELECT COUNT(*) FROM spatial_ref_sys").to_i
      return if count > 0

      connection.execute("SELECT InitSpatialMetadata(1)")
    end

    # Load the SpatiaLite extension and initialize spatial metadata.
    # Safe to call on every new connection / worker.
    def self.connect(connection = ActiveRecord::Base.connection)
      # The extension is already loaded by the initializer; we just ensure
      # spatial metadata exists for this connection's database file.
      init(connection)
    rescue ActiveRecord::StatementInvalid => e
      # spatial_ref_sys may not exist yet on a completely fresh database.
      # Call InitSpatialMetadata unconditionally in that case.
      raise unless e.message.include?("no such table")

      connection.execute("SELECT InitSpatialMetadata(1)")
    end
  end
end
