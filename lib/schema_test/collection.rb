require 'schema_test/property'

module SchemaTest
  class Collection < SchemaTest::Property::Object
    attr_reader :location

    def initialize(name, of_name, location: nil, version: nil, description: nil)
      super(name, version: version, description: description)
      @item_type = lookup_object(of_name, version)
      @location = location
      SchemaTest::Definition.register(self)
    end

    def as_json_schema(domain: SchemaTest.configuration.domain)
      id_part = version ? "v#{version}/#{name}" : name
      {
        '$schema' => SchemaTest::SCHEMA_VERSION,
        '$id' => "http://#{domain}/#{id_part}.json",
        'title' => name.to_s,
        'type' => 'array',
        'items' => @item_type.as_json_schema(false),
        'minItems' => 1
      }
    end
  end
end
