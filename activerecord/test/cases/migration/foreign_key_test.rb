require 'cases/helper'
require 'support/ddl_helper'
require 'support/schema_dumping_helper'

if ActiveRecord::Base.connection.supports_foreign_keys?
module ActiveRecord
  class Migration
    class ForeignKeyTest < ActiveRecord::TestCase
      include DdlHelper
      include SchemaDumpingHelper

      class Rocket < ActiveRecord::Base
      end

      class Astronaut < ActiveRecord::Base
      end

      setup do
        @connection = ActiveRecord::Base.connection
        @connection.create_table "rockets" do |t|
          t.string :name
        end

        @connection.create_table "astronauts" do |t|
          t.string :name
          t.references :rocket
        end
      end

      teardown do
        if defined?(@connection)
          @connection.execute "DROP TABLE IF EXISTS astronauts"
          @connection.execute "DROP TABLE IF EXISTS rockets"
        end
      end

      def test_foreign_keys
        foreign_keys = @connection.foreign_keys("fk_test_has_fk")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "fk_test_has_fk", fk.from_table
        assert_equal "fk_test_has_pk", fk.to_table
        assert_equal "fk_id", fk.column
        assert_equal "id", fk.primary_key
        assert_equal "fk_name", fk.name
      end

      def test_add_foreign_key_inferes_column
        @connection.add_foreign_key :astronauts, :rockets

        foreign_keys = @connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "astronauts", fk.from_table
        assert_equal "rockets", fk.to_table
        assert_equal "rocket_id", fk.column
        assert_equal "id", fk.primary_key
        assert_equal "astronauts_rocket_id_fk", fk.name
      end

      def test_add_foreign_key_with_column
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"

        foreign_keys = @connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal "astronauts", fk.from_table
        assert_equal "rockets", fk.to_table
        assert_equal "rocket_id", fk.column
        assert_equal "id", fk.primary_key
        assert_equal "astronauts_rocket_id_fk", fk.name
      end

      def test_add_foreign_key_with_non_standard_primary_key
        with_example_table @connection, "space_shuttles", "pk integer PRIMARY KEY" do
          @connection.add_foreign_key(:astronauts, :space_shuttles,
                                      column: "rocket_id", primary_key: "pk", name: "custom_pk")

          foreign_keys = @connection.foreign_keys("astronauts")
          assert_equal 1, foreign_keys.size

          fk = foreign_keys.first
          assert_equal "astronauts", fk.from_table
          assert_equal "space_shuttles", fk.to_table
          assert_equal "pk", fk.primary_key

          @connection.remove_foreign_key :astronauts, name: "custom_pk"
        end
      end

      def test_add_on_delete_restrict_foreign_key
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :restrict

        foreign_keys = @connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        if current_adapter?(:MysqlAdapter, :Mysql2Adapter)
          # ON DELETE RESTRICT is the default on MySQL
          assert_equal nil, fk.on_delete
        else
          assert_equal :restrict, fk.on_delete
        end
      end

      def test_add_on_delete_cascade_foreign_key
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :cascade

        foreign_keys = @connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal :cascade, fk.on_delete
      end

      def test_add_on_delete_nullify_foreign_key
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :nullify

        foreign_keys = @connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal :nullify, fk.on_delete
      end

      def test_add_foreign_key_with_on_update
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_update: :nullify

        foreign_keys = @connection.foreign_keys("astronauts")
        assert_equal 1, foreign_keys.size

        fk = foreign_keys.first
        assert_equal :nullify, fk.on_update
      end

      def test_add_foreign_key_with_too_long_identifier
        with_example_table @connection, "long_table_name_will_result_in_a_long_foreign_key_name", "rocket_id integer" do
          e = assert_raises(ArgumentError) do
            @connection.add_foreign_key "long_table_name_will_result_in_a_long_foreign_key_name", "rockets"
          end
          assert_match(/^Foreign key name 'long_table_name_will_result_in_a_long_foreign_key_name_rocket_id_fk' is too long;/, e.message)
        end
      end

      def test_remove_foreign_key_inferes_column
        @connection.add_foreign_key :astronauts, :rockets

        assert_equal 1, @connection.foreign_keys("astronauts").size
        @connection.remove_foreign_key :astronauts, :rockets
        assert_equal [], @connection.foreign_keys("astronauts")
      end

      def test_remove_foreign_key_by_column
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id"

        assert_equal 1, @connection.foreign_keys("astronauts").size
        @connection.remove_foreign_key :astronauts, column: "rocket_id"
        assert_equal [], @connection.foreign_keys("astronauts")
      end

      def test_remove_foreign_key_by_name
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", name: "fancy_named_fk"

        assert_equal 1, @connection.foreign_keys("astronauts").size
        @connection.remove_foreign_key :astronauts, name: "fancy_named_fk"
        assert_equal [], @connection.foreign_keys("astronauts")
      end

      def test_schema_dumping
        output = dump_table_schema "fk_test_has_fk"
        assert_match %r{\s+add_foreign_key "fk_test_has_fk", "fk_test_has_pk", column: "fk_id", primary_key: "id", name: "fk_name"$}, output
      end

      def test_schema_dumping_on_delete_and_on_update_options
        @connection.add_foreign_key :astronauts, :rockets, column: "rocket_id", on_delete: :nullify, on_update: :cascade

        output = dump_table_schema "astronauts"
        assert_match %r{\s+add_foreign_key "astronauts",.+on_update: :cascade,.+on_delete: :nullify$}, output
      end

      class CreateCitiesAndHousesMigration < ActiveRecord::Migration
        def change
          create_table("cities") { |t| }

          create_table("houses") do |t|
            t.column :city_id, :integer
          end
          add_foreign_key :houses, :cities, column: "city_id"
        end
      end

      def test_add_foreign_key_is_reversible
        migration = CreateCitiesAndHousesMigration.new
        silence_stream($stdout) { migration.migrate(:up) }
        assert_equal ["houses_city_id_fk"], @connection.foreign_keys("houses").map(&:name)
      ensure
        silence_stream($stdout) { migration.migrate(:down) }
      end
    end
  end
end
end
