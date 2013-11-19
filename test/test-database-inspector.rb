# Copyright (C) 2013  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

class DatabaseInspectorTest < Test::Unit::TestCase
  include GroongaTestUtils

  setup :setup_database, :before => :append

  private
  def report
    output = StringIO.new
    inspector = Groonga::DatabaseInspector.new(@database)
    inspector.report(output)
    output.string
  end

  def inspect_disk_usage(disk_usage)
    if disk_usage < (2 ** 20)
      "%.3fKiB" % (disk_usage / (2 ** 10).to_f)
    else
      "%.3fMiB" % (disk_usage / (2 ** 20).to_f)
    end
  end

  def inspect_table(table)
    <<-INSPECTED
    #{table.name}:
      ID:         #{table.id}
      Type:       #{inspect_table_type(table)}
      Key type:   #{inspect_key_type(table)}
      Path:       <#{table.path}>
      Disk usage: #{inspect_disk_usage(table.disk_usage)}
      N records:  #{table.size}
    INSPECTED
  end

  def inspect_table_type(table)
    case table
    when Groonga::Array
      "array"
    when Groonga::Hash
      "hash"
    when Groonga::PatriciaTrie
      "patricia trie"
    when Groonga::DoubleArrayTrie
      "double array trie"
    end
  end

  def inspect_key_type(table)
    if table.support_key?
      table.domain.name
    else
      "(no key)"
    end
  end

  class DatabaseTest < self
    def test_empty
      assert_equal(<<-INSPECTED, report)
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  0
  N tables:   0
  N columns:  0
  Plugins:
    None
  Tables:
    None
      INSPECTED
    end

    class NRecordsTest < self
      setup
      def setup_tables
        Groonga::Schema.define do |schema|
          schema.create_table("Users") do |table|
          end

          schema.create_table("Bookmarks") do |table|
          end
        end

        @users = context["Users"]
        @bookmarks = context["Bookmarks"]
      end

      def test_no_records
        assert_equal(inspected(0), report)
      end

      def test_has_records
        @users.add
        @users.add
        @bookmarks.add

        assert_equal(inspected(3), report)
      end

      private
      def inspected(n_records)
        <<-INSPECTED
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  #{n_records}
  N tables:   2
  N columns:  0
  Plugins:
    None
  Tables:
#{inspect_table(@bookmarks).chomp}
#{inspect_table(@users).chomp}
        INSPECTED
      end
    end

    class NTablesTest < self
      def test_no_tables
        assert_equal(inspected(0), report)
      end

      def test_has_tables
        Groonga::Schema.define do |schema|
          schema.create_table("Users") do |table|
          end

          schema.create_table("Bookmarks") do |table|
          end
        end

        assert_equal(inspected(2), report)
      end

      private
      def inspected(n_tables)
        inspected_tables = "  Tables:\n"
        if @database.tables.empty?
          inspected_tables << "    None\n"
        else
          @database.tables.each do |table|
            inspected_tables << inspect_table(table)
          end
        end

        <<-INSPECTED
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  0
  N tables:   #{n_tables}
  N columns:  0
  Plugins:
    None
#{inspected_tables.chomp}
        INSPECTED
      end
    end

    class NColumnsTest < self
      setup
      def setup_tables
        Groonga::Schema.define do |schema|
          schema.create_table("Users") do |table|
          end

          schema.create_table("Bookmarks") do |table|
          end
        end

        @users = context["Users"]
        @bookmarks = context["Bookmarks"]
      end

      def test_no_columns
        assert_equal(inspected(0), report)
      end

      def test_has_columns
        Groonga::Schema.define do |schema|
          schema.create_table("Users") do |table|
            table.short_text("name")
            table.int8("age")
          end

          schema.create_table("Bookmarks") do |table|
            table.text("description")
          end
        end

        assert_equal(inspected(3), report)
      end

      private
      def inspected(n_columns)
        <<-INSPECTED
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  0
  N tables:   2
  N columns:  #{n_columns}
  Plugins:
    None
  Tables:
#{inspect_table(@bookmarks).chomp}
#{inspect_table(@users).chomp}
        INSPECTED
      end
    end

    class PluginsTest < self
      def test_no_plugins
        assert_equal(inspected(<<-INSPECTED), report)
  Plugins:
    None
        INSPECTED
      end

      def test_has_plugin
        context.register_plugin("query_expanders/tsv")
        assert_equal(inspected(<<-INSPECTED), report)
  Plugins:
    * query_expanders/tsv#{Groonga::Plugin.suffix}
        INSPECTED
      end

      private
      def inspected(inspected_plugins)
        <<-INSPECTED
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  0
  N tables:   0
  N columns:  0
#{inspected_plugins.chomp}
  Tables:
    None
        INSPECTED
      end
    end
  end

  class TableTest < self
    class NoColumnTest < self
      def test_nothing
        assert_equal(inspected(<<-INSPECTED), report)
  Tables:
    None
        INSPECTED
      end

      def test_empty
        Groonga::Schema.define do |schema|
          schema.create_table("Users") do |table|
          end
        end
        users = context["Users"]

        assert_equal(inspected(<<-INSPECTED), report)
  Tables:
    Users:
      ID:         #{users.id}
      Type:       #{inspect_table_type(users)}
      Key type:   #{inspect_key_type(users)}
      Path:       <#{users.path}>
      Disk usage: #{inspect_disk_usage(users.disk_usage)}
      N records:  #{users.size}
        INSPECTED
      end

      private
      def inspected(inspected_tables)
        <<-INSPECTED
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  0
  N tables:   #{@database.tables.size}
  N columns:  0
  Plugins:
    None
#{inspected_tables.chomp}
        INSPECTED
      end
    end

    class NRecordsTest < self
      setup
      def setup_tables
        Groonga::Schema.define do |schema|
          schema.create_table("Users") do |table|
          end
        end
        @users = context["Users"]
      end

      def test_no_record
        assert_equal(inspected(0), report)
      end

      def test_empty
        @users.add
        @users.add
        @users.add

        assert_equal(inspected(3), report)
      end

      private
      def inspected(n_records)
        <<-INSPECTED
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  #{@users.size}
  N tables:   #{@database.tables.size}
  N columns:  0
  Plugins:
    None
  Tables:
    #{@users.name}:
      ID:         #{@users.id}
      Type:       #{inspect_table_type(@users)}
      Key type:   #{inspect_key_type(@users)}
      Path:       <#{@users.path}>
      Disk usage: #{inspect_disk_usage(@users.disk_usage)}
      N records:  #{n_records}
        INSPECTED
      end
    end

    class TypeTest < self
      def test_array
        Groonga::Schema.create_table("Users")
        @table = Groonga["Users"]
        assert_equal(inspected("array"), report)
      end

      def test_hash
        Groonga::Schema.create_table("Users",
                                     :type => :hash,
                                     :key_type => :short_text)
        @table = Groonga["Users"]
        assert_equal(inspected("hash"), report)
      end

      def test_patricia_trie
        Groonga::Schema.create_table("Users",
                                     :type => :patricia_trie,
                                     :key_type => :short_text)
        @table = Groonga["Users"]
        assert_equal(inspected("patricia trie"), report)
      end

      def test_double_array_trie
        Groonga::Schema.create_table("Users",
                                     :type => :double_array_trie,
                                     :key_type => :short_text)
        @table = Groonga["Users"]
        assert_equal(inspected("double array trie"), report)
      end

      private
      def inspected(type)
        <<-INSPECTED
Database
  Path:       <#{@database_path}>
  Disk usage: #{inspect_disk_usage(@database.disk_usage)}
  N records:  #{@table.size}
  N tables:   #{@database.tables.size}
  N columns:  0
  Plugins:
    None
  Tables:
    #{@table.name}:
      ID:         #{@table.id}
      Type:       #{type}
      Key type:   #{inspect_key_type(@table)}
      Path:       <#{@table.path}>
      Disk usage: #{inspect_disk_usage(@table.disk_usage)}
      N records:  #{@table.size}
        INSPECTED
      end
    end
  end
end
