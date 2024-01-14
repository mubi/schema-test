require 'schema_test'

module SchemaTest
  module Minitest
    def assert_valid_json_for_schema(json, name, version)
      definition = SchemaTest::Definition.find(name, version)

      raise "Unknown definition #{name}, version: #{version}" unless definition.present?

      errors = SchemaTest.validate_json(json, definition)

      assert_empty errors, "JSON did not pass schema:\n#{errors.join("\n")}"
    end
  end
end
