require 'spec_helper'
require 'tmpdir'
require 'json'

RSpec.describe 'SchemaTest.compile!' do
  let(:definition_path) { Dir.mktmpdir }
  let(:compiled_path) { File.join(definition_path, 'compiled') }

  before do
    SchemaTest.configure do |config|
      config.definition_paths << definition_path
    end
  end

  after do
    FileUtils.remove_entry(definition_path)
  end

  it 'creates a compiled directory within the definition path' do
    SchemaTest::Definition.new(:thing, properties: [SchemaTest::Property::String.new(:name)])

    SchemaTest.compile!

    expect(Dir.exist?(compiled_path)).to be true
  end

  it 'writes each definition as a JSON file' do
    SchemaTest::Definition.new(:widget, properties: [
      SchemaTest::Property::String.new(:name),
      SchemaTest::Property::Integer.new(:count)
    ])

    SchemaTest.compile!

    json_path = File.join(compiled_path, 'widget.json')
    expect(File.exist?(json_path)).to be true

    schema = JSON.parse(File.read(json_path))
    expect(schema['$schema']).to eq 'http://json-schema.org/draft-07/schema#'
    expect(schema['title']).to eq 'widget'
    expect(schema['properties']).to have_key('name')
    expect(schema['properties']).to have_key('count')
  end

  it 'includes the version in the filename for versioned definitions' do
    SchemaTest::Definition.new(:gadget, version: 1, properties: [
      SchemaTest::Property::String.new(:name)
    ])

    SchemaTest::Definition.new(:gadget, version: 2, properties: [
      SchemaTest::Property::String.new(:name),
      SchemaTest::Property::String.new(:description)
    ])

    SchemaTest.compile!

    v1_schema = JSON.parse(File.read(File.join(compiled_path, 'gadget.v1.json')))
    expect(v1_schema['title']).to eq 'gadget'
    expect(v1_schema['properties'].keys).to eq ['name']

    v2_schema = JSON.parse(File.read(File.join(compiled_path, 'gadget.v2.json')))
    expect(v2_schema['title']).to eq 'gadget'
    expect(v2_schema['properties'].keys).to eq ['name', 'description']
  end

  it 'writes pretty-printed JSON with a trailing newline' do
    SchemaTest::Definition.new(:item, properties: [SchemaTest::Property::String.new(:name)])

    SchemaTest.compile!

    content = File.read(File.join(compiled_path, 'item.json'))
    expect(content).to end_with("\n")
    expect(content).to include("\n  ")
  end

  it 'mirrors the layout of the original definition files' do
    SchemaTest::Definition.new(:film, location: 'api/v3/film.rb:5', properties: [
      SchemaTest::Property::String.new(:name)
    ])

    SchemaTest.compile!

    json_path = File.join(compiled_path, 'api', 'v3', 'film.json')
    expect(File.exist?(json_path)).to be true

    schema = JSON.parse(File.read(json_path))
    expect(schema['title']).to eq 'film'
  end

  it 'mirrors the layout for versioned definitions' do
    SchemaTest::Definition.new(:film, version: 2, location: 'api/v3/film.rb:5', properties: [
      SchemaTest::Property::String.new(:name)
    ])

    SchemaTest.compile!

    json_path = File.join(compiled_path, 'api', 'v3', 'film.v2.json')
    expect(File.exist?(json_path)).to be true
  end

  it 'writes definitions without a location to the root of the compiled directory' do
    SchemaTest::Definition.new(:loose, properties: [SchemaTest::Property::String.new(:name)])

    SchemaTest.compile!

    expect(File.exist?(File.join(compiled_path, 'loose.json'))).to be true
  end

  it 'compiles collection definitions' do
    SchemaTest::Definition.new(:thing, properties: [SchemaTest::Property::String.new(:name)])
    SchemaTest::Collection.new(:things, :thing)

    SchemaTest.compile!

    expect(File.exist?(File.join(compiled_path, 'thing.json'))).to be true
    expect(File.exist?(File.join(compiled_path, 'things.json'))).to be true

    collection_schema = JSON.parse(File.read(File.join(compiled_path, 'things.json')))
    expect(collection_schema['type']).to eq 'array'
  end
end

RSpec.describe 'SchemaTest.compile! with multiple definition paths' do
  let(:path_a) { Dir.mktmpdir }
  let(:path_b) { Dir.mktmpdir }

  before do
    SchemaTest.configure do |config|
      config.definition_paths << path_a
      config.definition_paths << path_b
    end
  end

  after do
    FileUtils.remove_entry(path_a)
    FileUtils.remove_entry(path_b)
  end

  it 'writes each schema once, into the compiled directory of its owning path' do
    FileUtils.mkdir_p(File.join(path_a, 'api', 'v3'))
    File.write(File.join(path_a, 'api', 'v3', 'film.rb'), <<~RUBY)
      SchemaTest.define :film do
        string :name
      end
    RUBY

    SchemaTest.compile!

    expect(File.exist?(File.join(path_a, 'compiled', 'api', 'v3', 'film.json'))).to be true
    expect(File.exist?(File.join(path_b, 'compiled', 'api', 'v3', 'film.json'))).to be false
    expect(Dir.exist?(File.join(path_b, 'compiled'))).to be false
  end
end

RSpec.describe 'SchemaTest.load_compiled_schema' do
  let(:definition_path) { Dir.mktmpdir }
  let(:compiled_path) { File.join(definition_path, 'compiled') }

  before do
    SchemaTest.configure do |config|
      config.definition_paths << definition_path
    end
  end

  after do
    FileUtils.remove_entry(definition_path)
  end

  it 'loads an unversioned compiled schema from disk' do
    SchemaTest::Definition.new(:widget, properties: [
      SchemaTest::Property::String.new(:name)
    ])
    SchemaTest.compile!

    schema = SchemaTest.load_compiled_schema(:widget)
    expect(schema['title']).to eq 'widget'
    expect(schema['properties']).to have_key('name')
  end

  it 'loads a versioned compiled schema from disk' do
    SchemaTest::Definition.new(:gadget, version: 2, properties: [
      SchemaTest::Property::String.new(:name)
    ])
    SchemaTest.compile!

    schema = SchemaTest.load_compiled_schema(:gadget, version: 2)
    expect(schema['title']).to eq 'gadget'
    expect(schema['$id']).to include('v2')
  end

  it 'loads a compiled schema nested in a mirrored subdirectory' do
    SchemaTest::Definition.new(:film, location: 'api/v3/film.rb:5', properties: [
      SchemaTest::Property::String.new(:name)
    ])
    SchemaTest.compile!

    schema = SchemaTest.load_compiled_schema(:film)
    expect(schema['title']).to eq 'film'
    expect(schema['properties']).to have_key('name')
  end

  it 'raises an error when the compiled schema is not found' do
    expect {
      SchemaTest.load_compiled_schema(:nonexistent, version: 1)
    }.to raise_error(SchemaTest::Error, /Could not find compiled schema/)
  end
end

RSpec.describe 'compiled configuration' do
  it 'defaults to false' do
    expect(SchemaTest.configuration.compiled).to be false
  end

  it 'can be toggled on' do
    SchemaTest.configure do |config|
      config.compiled = true
    end
    expect(SchemaTest.configuration.compiled).to be true
  end
end
