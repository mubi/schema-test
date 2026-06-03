require 'json'
require 'digest'
require 'schema_test/version'
require 'schema_test/rewriter'
require 'schema_test/fingerprint_rewriter'
require 'schema_test/collapser'
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
      definition = SchemaTest::Definition.new(name, location: definition_location(caller[0]), **attributes, &block)
      if collection
        collection(collection, of: name, version: attributes[:version])
      end
      definition
    end

    # Explicitly define a new schema collection (an array of other schema
    # objects)
    def collection(name, of:, **attributes)
      SchemaTest::Collection.new(name, of, location: definition_location(caller[1]), **attributes)
    end

    # Compile all definitions to JSON Schema files in a `compiled`
    # directory within each definition path. The compiled files mirror
    # the layout of the original definition files, so a definition
    # declared in `api/v3/film.rb` is written to
    # `compiled/api/v3/film.json`.
    def compile!
      load_definitions
      SchemaTest::Definition.all.each do |definition|
        begin
          definition_path = owning_definition_path(definition)
          next unless definition_path
          path = Pathname.new(definition_path).join('compiled', compiled_relative_path(definition))
          path.dirname.mkpath
          File.write(path, JSON.pretty_generate(definition.as_json_schema) + "\n")
        rescue => e
          warn "SchemaTest: failed to compile #{definition.name} (version: #{definition.version}): #{e.message}"
        end
      end
    end

    # Load a pre-compiled JSON schema from the compiled directory.
    # Because compiled files mirror the original definition layout, the
    # file may live in a nested subdirectory, so the compiled tree is
    # searched recursively for the expected filename.
    def load_compiled_schema(name, version: nil)
      filename = compiled_filename(name, version)
      configuration.definition_paths.each do |definition_path|
        compiled_root = Pathname.new(definition_path).join('compiled')
        match = Pathname.glob(compiled_root.join('**', filename)).first
        return JSON.parse(match.read) if match
      end
      raise SchemaTest::Error, "Could not find compiled schema for #{name.inspect} (version: #{version.inspect})"
    end

    # A stable fingerprint of a compiled schema. The fingerprint is
    # derived from the schema's semantic content, so it changes whenever
    # the schema changes but is unaffected by pretty-print formatting.
    def schema_fingerprint(schema)
      Digest::SHA256.hexdigest(JSON.generate(schema))
    end

    # Collapse expanded schema assertions in test files back to
    # simple one-line calls. Pass file paths or directory paths.
    # Directories are globbed for **/*.rb files.
    def collapse!(*paths)
      files = paths.flat_map do |path|
        if File.directory?(path)
          Dir[File.join(path, '**', '*.rb')]
        else
          [path]
        end
      end
      files.each do |file|
        contents = File.read(file)
        next unless contents.include?(OPENING_COMMENT)
        collapser = SchemaTest::Collapser.new(contents)
        File.write(file, collapser.output)
      end
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

    # The filename a definition compiles to, e.g. `film.json` or
    # `film.v2.json` for versioned definitions.
    def compiled_filename(name, version)
      if version
        "#{name}.v#{version}.json"
      else
        "#{name}.json"
      end
    end

    # The relative source file a definition was declared in (without the
    # trailing line number), or nil if it has no known location.
    def definition_source_file(definition)
      return nil unless definition.location
      source = definition.location.rpartition(':').first
      source = definition.location if source.empty?
      source.empty? ? nil : source
    end

    # The definition path a definition's source file lives under, so
    # that each schema is compiled exactly once into the `compiled`
    # directory of its owning path rather than duplicated into every
    # definition path. Definitions whose source cannot be located (for
    # example, those constructed directly without a location) fall back
    # to the first configured definition path.
    def owning_definition_path(definition)
      source = definition_source_file(definition)
      if source
        owning = configuration.definition_paths.find do |definition_path|
          Pathname.new(definition_path).join(source).exist?
        end
        return owning if owning
      end
      configuration.definition_paths.first
    end

    # The path a definition compiles to, relative to the `compiled`
    # directory. The directory mirrors the location of the source
    # definition file (e.g. `api/v3/film.rb` -> `api/v3/film.json`).
    # Definitions without a known location are written to the root of
    # the compiled directory.
    def compiled_relative_path(definition)
      filename = compiled_filename(definition.name, definition.version)
      source = definition_source_file(definition)
      return Pathname.new(filename) unless source
      Pathname.new(source).dirname.join(filename)
    end

    def definition_location(caller_line)
      path, line = caller_line.split(':').take(2)
      configuration.definition_paths.each do |definition_path|
        if path.start_with?(definition_path.to_s)
          path = Pathname.new(path).relative_path_from(definition_path)
          break
        end
      end
      [path, line].join(':')
    end

    def load_definitions
      configuration.definition_paths.map! { |p| Pathname.new(p) }
      globbed_paths = configuration.definition_paths.map { |path| path.join('**', '*.rb').to_s }
      Dir[*globbed_paths].each do |schema_file|
        require schema_file
      end
    end

  end
end
