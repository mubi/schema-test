require 'schema_test'

module SchemaTest
  module Minitest
    class << self
      attr_accessor :calls_for_expansion, :expansion_hook_installed
    end
    self.calls_for_expansion = {}
    self.expansion_hook_installed = false

    def assert_valid_json_for_schema(json, name, arguments)
      install_assert_api_expansion_hook

      version = arguments[:version]
      schema = arguments[:schema]

      definition = SchemaTest::Definition.find(name, version)
      raise "Unknown definition #{name}, version: #{version}" unless definition.present?

      expected_schema = definition.as_json_schema

      flunk "Outdated API schema assertion at #{caller[0]}" if schema != expected_schema && ENV['CI']

      call = schema_call(__method__, name, version, definition, expected_schema)
      queue_write_expanded_assert_api_call(caller[0], call)

      assert_json_schema_validates_against(json, expected_schema)
    end

    def assert_json_schema_validates_against(json, schema)
      errors = SchemaTest.validate_json(json, schema)
      assert errors.empty?, "JSON did not pass schema:\n#{errors.join("\n")}"
    end

    private

    def schema_call(method, name, version, definition, expected_schema)
      SchemaTest::Rewriter::SchemaCall.new(
        nil, method, name, version, definition.location, expected_schema
      )
    end

    def queue_write_expanded_assert_api_call(call_site, schema_call)
      file, line = call_site.split(':')
      schema_call.line_index = line.to_i.pred

      registry = SchemaTest::Minitest.calls_for_expansion
      registry[file] ||= []
      if (existing_call = registry[file].find { |call| schema_call.line_index == call.line_index })
        return if existing_call == schema_call

        raise "Expected schema does not match for duplicate API schema assertion at #{call_site}"
      end
      registry[file] << schema_call
    end

    def install_assert_api_expansion_hook
      return if SchemaTest::Minitest.expansion_hook_installed

      at_exit { expand_assert_api_calls }
      SchemaTest::Minitest.expansion_hook_installed = true
    end

    def expand_assert_api_calls
      SchemaTest::Minitest.calls_for_expansion.each do |file, schema_calls|
        original_contents = File.read(file)
        rewriter_options = { disable_rubocop: SchemaTest.configuration.disable_rubocop }
        rewriter = SchemaTest::Rewriter.new(original_contents, schema_calls, options: rewriter_options)
        new_contents = rewriter.output
        raise 'Error rewriting file' if new_contents.blank?

        File.open(file, 'w') { |f| f.puts new_contents }
      end
    end
  end
end
