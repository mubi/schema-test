require 'schema_test/version'
require 'schema_test/rewriter'
require 'schema_test/definition'
require 'schema_test/collection'
require 'schema_test/validator'
require 'schema_test/configuration'

module SchemaTest
  class Error < StandardError; end

  SCHEMA_VERSION = "http://json-schema.org/draft-07/schema#"

  class << self
    def reset!
      @configuration = nil
      SchemaTest::Definition.reset!
    end

    # Yields a configuration object, which can be used to set up
    # various aspects of the library
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= SchemaTest::Configuration.new
    end

    # Recursively loads all files under the `definition_paths` directories
    def load!
      load_definitions
    end

    # Define a new schema
    def define(name, collection: nil, **attributes, &block)
      definition = SchemaTest::Definition.new(name, attributes, &block)
      if collection
        collection(collection, of: name, version: attributes[:version])
      end
      definition
    end

    # Explicitly define a new schema collection (an array of other schema
    # objects)
    def collection(name, of:, **attributes)
      SchemaTest::Collection.new(name, of, attributes)
    end

    # Validate some JSON data against a schema or schema definition
    def validate_json(json, definition_or_schema)
      validator = SchemaTest::Validator.new(json)
      if definition_or_schema.is_a?(SchemaTest::Property::Object)
        validator.validate_using_definition(definition_or_schema)
      else
        validator.validate_using_json_schema(definition_or_schema)
      end
    end

    private

    def load_definitions
      globbed_paths = configuration.definition_paths.map { |path| path.join('**', '*.rb') }
      Dir[globbed_paths.join(',')].each do |schema_file|
        require schema_file
      end
    end

  end
end
