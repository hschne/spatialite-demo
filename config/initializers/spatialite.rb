SPATIALITE_TABLES = %w[
  geometry_columns
  geometry_columns_auth
  geometry_columns_field_infos
  geometry_columns_statistics
  geometry_columns_time
  views_geometry_columns
  views_geometry_columns_auth
  views_geometry_columns_field_infos
  views_geometry_columns_statistics
  virts_geometry_columns
  virts_geometry_columns_auth
  virts_geometry_columns_field_infos
  virts_geometry_columns_statistics
  spatial_ref_sys
  spatial_ref_sys_aux
  spatialite_history
  sql_statements_log
  data_licenses
  ElementaryGeometries
  KNN2
  SpatialIndex
].freeze

SPATIALITE_TABLE_REGEX = /^idx_\w+_\w+$/

ActiveSupport.on_load(:active_record_sqlite3adapter) do
  ignore_tables = ::ActiveRecord::SchemaDumper.ignore_tables
  SPATIALITE_TABLES.each { |t| ignore_tables << t }
  ignore_tables << SPATIALITE_TABLE_REGEX
  ignore_tables.uniq!
end

# Protect spatial_ref_sys (and other SpatiaLite system tables) from being
# emptied when Rails parallel test workers call truncate_tables to reset state.
# Without this guard, geodesic Distance(..., 1) returns NULL because the 6559
# SRID rows are wiped between worker resets.
ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/abstract/database_statements"

  ActiveRecord::ConnectionAdapters::DatabaseStatements.prepend(Module.new do
    def truncate_tables(*table_names)
      safe_names = table_names.reject do |name|
        SPATIALITE_TABLES.include?(name) || name.match?(SPATIALITE_TABLE_REGEX)
      end
      super(*safe_names)
    end
  end)
end

ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/sqlite3_adapter"

  ActiveRecord::ConnectionAdapters::SQLite3Adapter.send(
    :remove_const,
    :VIRTUAL_TABLE_REGEX
  )
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.const_set(
    :VIRTUAL_TABLE_REGEX,
    /USING\s+(\w+)\s*\((.*)\)/i
  )

  require "active_record/connection_adapters/sqlite3/schema_dumper"

  ActiveRecord::ConnectionAdapters::SQLite3::SchemaDumper.class_eval do
    private

    def virtual_tables(stream)
      virtual_tables = @connection.virtual_tables.reject { |name, _| ignored?(name) }
      return if virtual_tables.empty?

      stream.puts
      stream.puts "  # Virtual tables defined in this database."
      stream.puts "  # Note that virtual tables may not work with other database engines. Be careful if changing database."
      virtual_tables.sort.each do |table_name, options|
        module_name, arguments = options
        stream.puts "  create_virtual_table #{table_name.inspect}, #{module_name.inspect}, #{arguments.split(", ").inspect}"
      end
    end
  end
end
