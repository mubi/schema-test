require 'schema_test'

module SchemaTest
  module Minitest
    def assert_valid_json_for_schema(json, name, arguments)
      install_assert_api_expansion_hook

      version = arguments[:version]
      schema = arguments[:schema]

      definition = SchemaTest::Definition.find(name, version)
      raise "Unknown definition #{name}, version: #{version}" unless definition.present?

      expected_schema = definition.as_json_schema

      if schema != expected_schema && ENV['CI']
        flunk "Outdated API schema assertion at #{caller[0]}"
      end

      queue_write_expanded_assert_api_call(caller[0], __method__, name, version, definition.location, expected_schema)

      assert_json_schema_validates_against(json, expected_schema)
    end

    def assert_json_schema_validates_against(json, schema)
      errors = SchemaTest.validate_json(json, schema)
      assert errors.empty?, "JSON did not pass schema:\n#{errors.join("\n")}"
    end

    private

    @@__api_schema_calls_for_expansion = {}
    @@__api_schema_expansion_hook_installed = false

    def queue_write_expanded_assert_api_call(call_site, method, name, version, location, expected_schema)
      file, line = call_site.split(':')
      line_index = line.to_i.pred
      schema_call = [line_index, method, name, version, location, expected_schema]

      @@__api_schema_calls_for_expansion[file] ||= []
      if (existing_call = @@__api_schema_calls_for_expansion[file].find { |call| line_index == call[0] })
        return if existing_call == schema_call
        raise "Expected schema does not match for duplicate API schema assertion at #{call_site}"
      end
      @@__api_schema_calls_for_expansion[file] << [line_index, method, name, version, location, expected_schema]
    end

    def install_assert_api_expansion_hook
      return if @@__api_schema_expansion_hook_installed
      at_exit { expand_assert_api_calls }
      @@__api_schema_expansion_hook_installed = true
    end

    def expand_assert_api_calls
     @@__api_schema_calls_for_expansion.each do |file, line_indexes_with_schemas|
       original_contents = File.read(file)
       rewriter = SchemaTest::Rewriter.new(original_contents, line_indexes_with_schemas)
       new_contents = rewriter.output
       raise "Error rewriting file" if new_contents.blank?
       File.open(file, 'w') { |f| f.puts new_contents }
     end
    end
  end
end
