require 'spec_helper'

RSpec.describe 'transforming to JSON Schema' do
  it 'captures definitions of schemas using various types' do
    definition = SchemaTest.define :thing, version: 4 do
      integer :count
      string :name
      float :angle
      boolean :flag, desc: 'with a description'
      array :subthings, of: :integer
      datetime :published_at
      url :source_uri
      html :description
    end

    expected_json_schema = {
      '$schema' => 'http://json-schema.org/draft-07/schema#',
      '$id' => 'http://example.com/v4/thing.json',
      'title' => 'thing',
      'type' => 'object',
      'properties' => {
        'count' => { 'type' => 'integer' },
        'name' => { 'type' => 'string' },
        'angle' => { 'type' => 'number' },
        'flag' => { 'type' => 'boolean', 'description' => 'with a description' },
        'subthings' => { 'type' => 'array', 'items' => { 'type' => 'integer' } },
        'published_at' => { 'type' => 'string', 'format' => 'date-time' },
        'source_uri' => { 'type' => 'string', 'format' => 'uri' },
        'description' => { 'type' => 'string' }
      },
      'required' => ['count', 'name', 'angle', 'flag', 'subthings', 'published_at', 'source_uri', 'description'],
      'additionalProperties' => false
    }
    expect(definition.as_json_schema).to eq(expected_json_schema)
  end

  it 'includes all required properties in required list' do
    definition = SchemaTest.define :thing do
      string :name
      optional string :optional_subname
    end

    json_schema = definition.as_json_schema
    expect(json_schema['required']).to eq(['name'])
  end

  it 'includes the version of the schema' do
    definition = SchemaTest.define :thing, version: 123 do
      string :name
    end

    json_schema = definition.as_json_schema
    expect(json_schema['$id']).to match(/\/v123\/thing.json/)
  end

  it 'allows defining the domain for the schema' do
    SchemaTest.configure do |config|
      config.domain = 'mydomain.com'
    end

    definition = SchemaTest.define :thing do
      string :name
    end

    expect(definition.as_json_schema['$id']).to eq('http://mydomain.com/thing.json')
  end

  it 'expands nested objects' do
    definition = SchemaTest.define :thing do
      string :name
      object :coordinates do
        float :latitude
        float :longitude
      end
    end

    expected_json_schema = {
      '$schema' => 'http://json-schema.org/draft-07/schema#',
      '$id' => 'http://example.com/thing.json',
      'title' => 'thing',
      'type' => 'object',
      'properties' => {
        'name' => { 'type' => 'string' },
        'coordinates' => {
          'type' => 'object',
          'properties' => {
            'latitude' => { 'type' => 'number' },
            'longitude' => { 'type' => 'number' }
          },
          'required' => ['latitude', 'longitude'],
          'additionalProperties' => false
        }
      },
      'required' => ['name', 'coordinates'],
      'additionalProperties' => false
    }
    expect(definition.as_json_schema).to eq(expected_json_schema)
  end

  it 'allows definitions of arrays with specific object types' do
    SchemaTest.define :subthing do
      string :name
    end
    thing = SchemaTest.define :thing do
      array :subthings, of: type(:subthing)
    end

    expected_json_schema = {
      '$schema' => 'http://json-schema.org/draft-07/schema#',
      '$id' => 'http://example.com/thing.json',
      'title' => 'thing',
      'type' => 'object',
      'properties' => {
        'subthings' => { 'type' => 'array', 'items' => {
                          'type' => 'object',
                          'properties' => { 'name' => { 'type' => 'string' }},
                          'required' => ['name'],
                          'additionalProperties' => false
                        }
                      },
      },
      'required' => ['subthings'],
      'additionalProperties' => false
    }

    expect(thing.as_json_schema).to eq(expected_json_schema)
  end

  it 'allows definitions of arrays with anonymous object types' do
    thing = SchemaTest.define :thing do
      array :subthings do
        string :name
      end
    end

    expected_json_schema = {
      '$schema' => 'http://json-schema.org/draft-07/schema#',
      '$id' => 'http://example.com/thing.json',
      'title' => 'thing',
      'type' => 'object',
      'properties' => {
        'subthings' => { 'type' => 'array', 'items' => {
                          'type' => 'object',
                          'properties' => { 'name' => { 'type' => 'string' }},
                          'required' => ['name'],
                          'additionalProperties' => false
                        }
                      },
      },
      'required' => ['subthings'],
      'additionalProperties' => false
    }

    expect(thing.as_json_schema).to eq(expected_json_schema)
  end

  describe 'nested objects' do
    before do
      SchemaTest.define :animal do
        string :species
      end
      SchemaTest.define :address do
        string :postcode
      end
    end

    let(:zoo) do
      SchemaTest.define :zoo do
        string :name
        object :address
        array :animals, of: type(:animal)
      end
    end

    it 'expands nested objects from other schema definitions' do
      expected_json_schema = {
        '$schema' => 'http://json-schema.org/draft-07/schema#',
        '$id' => 'http://example.com/zoo.json',
        'title' => 'zoo',
        'type' => 'object',
        'properties' => {
          'name' => { 'type' => 'string' },
          'address' => { 'type' => 'object', 'properties' => { 'postcode' => { 'type' => 'string' } }, 'required' => ['postcode'], 'additionalProperties' => false },
          'animals' => { 'type' => 'array', 'items' => { 'type' => 'object', 'properties' => { 'species' => { 'type' => 'string' }}, 'required' => ['species'], 'additionalProperties' => false }}
        },
        'required' => ['name', 'address', 'animals'],
        'additionalProperties' => false
      }
      expect(zoo.as_json_schema).to eq(expected_json_schema)
    end

    it 'allows aliasing of nested objects' do
      jungle = SchemaTest.define :jungle do
        object :animal, as: :apex_predator
      end

      expected_json_schema = {
        '$schema' => 'http://json-schema.org/draft-07/schema#',
        '$id' => 'http://example.com/jungle.json',
        'title' => 'jungle',
        'type' => 'object',
        'properties' => {
          'apex_predator' => { 'type' => 'object', 'properties' => { 'species' => { 'type' => 'string' } }, 'required' => ['species'], 'additionalProperties' => false }
        },
        'required' => ['apex_predator'],
        'additionalProperties' => false
      }
      expect(jungle.as_json_schema).to eq(expected_json_schema)
    end

    it 'allows nested custom types' do
      hunter = SchemaTest.define :hunter do
        object :collections do
          array :animals, of: type(:animal)
        end
      end

      expected_json_schema = {
        '$schema' => 'http://json-schema.org/draft-07/schema#',
        '$id' => 'http://example.com/hunter.json',
        'title' => 'hunter',
        'type' => 'object',
        'properties' => {
          'collections' => { 'type' => 'object', 'properties' => { 'animals' => { 'type' => 'array', 'items' =>  { 'type' => 'object', 'properties' => { 'species' => { 'type' => 'string' }}, 'required' => ['species'], 'additionalProperties' => false }} }, 'required' => ['animals'], 'additionalProperties' => false }
        },
        'required' => ['collections'],
        'additionalProperties' => false
      }
      expect(hunter.as_json_schema).to eq(expected_json_schema)
    end
  end

  it 'allows creation of bare collections of objects' do
    SchemaTest.define :thing do
      string :name
    end

    things = SchemaTest.collection :things, of: :thing

    expected_json_schema = {
      '$schema' => 'http://json-schema.org/draft-07/schema#',
      '$id' => 'http://example.com/things.json',
      'title' => 'things',
      'type' => 'array',
      'items' => {
        'type' => 'object',
        'properties' => { 'name' => { 'type' => 'string' } },
        'required' => ['name'],
        'additionalProperties' => false
      },
      'minItems' => 1
    }
    expect(things.as_json_schema).to eq(expected_json_schema)
  end

  it 'raises an error if a referenced object cannot be found' do
    thing = SchemaTest.define :thing do
      object :missing_thing
    end

    expect { thing.as_json_schema }.to raise_error(SchemaTest::Error)
  end

  it 'raises an error if a definition basis cannot be found' do
    thing = SchemaTest.define :thing do
      based_on :missing_thing
    end

    expect { thing.as_json_schema }.to raise_error(SchemaTest::Error)
  end

  pending 'raises an error if a circular definition is made' do
    thing = SchemaTest.define :thing do
      based_on :other_thing
    end

    other_thing = SchemaTest.define :other_thing do
      based_on :thing
    end

    expect { thing.as_json_schema }.to raise_error(SchemaTest::Error)
  end
end
