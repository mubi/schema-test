module SchemaTest
  class TestHelper
    def assert_api_schema(name, version:, structure: nil)
      install_asset_api_expansion_hook

      definition = ApiSchema::Definition.find(name, version)
      raise "Unknown definition #{name}, version: #{version}" unless definition.present?

      expected_structure = definition.as_structure

      if structure != expected_structure
        if ENV['CI']
          flunk "Outdated API schema assertion at #{caller[0]}"
        else
          queue_write_expanded_assert_api_call(caller[0], __method__, name, version, expected_structure)
        end
      end

      assert_json_response_structure(*expected_structure)
    end

    private

    @@__api_schema_calls_for_expansion = {}
    @@__api_schema_expansion_hook_installed = false

    def queue_write_expanded_assert_api_call(call_site, method, name, version, expected_structure)
      file, line = call_site.split(':')
      line_index = line.to_i.pred

      @@__api_schema_calls_for_expansion[file] ||= []
      @@__api_schema_calls_for_expansion[file] << [line_index, method, name, version, expected_structure]
    end

    def install_asset_api_expansion_hook
      return if @@__api_schema_expansion_hook_installed
      at_exit { expand_assert_api_calls }
      @@__api_schema_expansion_hook_installed = true
    end

    def expand_assert_api_calls
      @@__api_schema_calls_for_expansion.each do |file, line_indexes_with_structures|
        rewriter = SchemaTest::Rewriter.new(File.read(file), line_indexes_with_structures)
        File.open(file, 'w') { f.puts rewriter.output }
      end
    end
  end
end

if const_defined?(Rails)
  ActionController::TestCase.send(:include, SchemaTest::TestHelper)
  ActionDispatch::IntegrationTest.send(:include, SchemaTest::TestHelper)

  SchemaTest.definition_paths << Rails.root.join('test', 'schema_definitions', '**', '*.rb')
  SchemaTest.definition_paths << Rails.root.join('spec', 'schema_definitions', '**', '*.rb')

  SchemaTest.load_definitions
end

