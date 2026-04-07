module ActiveRecord
  module Spatialite
    def self.init(connection = ActiveRecord::Base.connection)
      count = connection.select_value("SELECT COUNT(*) FROM spatial_ref_sys").to_i
      return if count > 0

      connection.execute("SELECT InitSpatialMetadata(1)")
    rescue ActiveRecord::StatementInvalid
      connection.execute("SELECT InitSpatialMetadata(1)")
    end
  end
end
