require 'spec_helper'
require 'schema_test/pretty_printer'

RSpec.describe SchemaTest::PrettyPrinter do
  def format(value, **opts)
    described_class.format(value, **opts)
  end

  describe 'primitives' do
    it 'formats nil' do
      expect(format(nil)).to eq('nil')
    end

    it 'formats booleans' do
      expect(format(true)).to eq('true')
      expect(format(false)).to eq('false')
    end

    it 'formats integers and floats' do
      expect(format(42)).to eq('42')
      expect(format(1.23)).to eq('1.23')
    end

    it 'formats symbols' do
      expect(format(:foo)).to eq(':foo')
    end

    it 'formats strings with single quotes' do
      expect(format('hello')).to eq("'hello'")
    end

    it 'falls back to inspect for strings containing single quotes' do
      expect(format("it's")).to eq('"it\'s"')
    end

    it 'falls back to inspect for strings containing backslashes' do
      expect(format('a\\b')).to eq('"a\\\\b"')
    end
  end

  describe 'arrays' do
    it 'formats short arrays inline' do
      expect(format([1, 2, 3])).to eq('[1, 2, 3]')
    end

    it 'formats empty arrays' do
      expect(format([])).to eq('[]')
    end

    it 'formats arrays of strings inline' do
      expect(format(['a b', 'c d'])).to eq("['a b', 'c d']")
    end

    it 'uses %w[] for arrays of bareword strings' do
      expect(format(['number', 'null'])).to eq('%w[number null]')
    end

    it 'keeps single-element string arrays as bracket form' do
      expect(format(['only'])).to eq("['only']")
    end

    it 'wraps long arrays across multiple lines' do
      result = format(['aaaaaaaaaa'] * 10, width: 40)
      expect(result).to eq(<<~OUT.chomp)
        [
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa',
          'aaaaaaaaaa'
        ]
      OUT
    end
  end

  describe 'hashes' do
    it 'formats empty hashes' do
      expect(format({})).to eq('{}')
    end

    it 'uses symbol shorthand for symbol keys' do
      expect(format({ name: 'Bob', age: 30 })).to eq("{ name: 'Bob', age: 30 }")
    end

    it 'uses hash rocket with spaces for string keys' do
      expect(format({ 'name' => 'Bob' })).to eq("{ 'name' => 'Bob' }")
    end

    it 'wraps long hashes across multiple lines' do
      result = format({ first_name: 'Alexander', last_name: 'Hamilton' }, width: 40)
      expect(result).to eq(<<~OUT.chomp)
        {
          first_name: 'Alexander',
          last_name: 'Hamilton'
        }
      OUT
    end

    it 'keeps the opening brace on the key line when wrapping nested hashes' do
      schema = {
        'properties' => {
          'name' => { 'type' => 'string' },
          'age' => { 'type' => 'integer' }
        }
      }
      result = format(schema, width: 40)
      expect(result).to eq(<<~OUT.chomp)
        {
          'properties' => {
            'name' => { 'type' => 'string' },
            'age' => { 'type' => 'integer' }
          }
        }
      OUT
    end

    it 'wraps deeply nested arrays inside hashes' do
      schema = { 'type' => ['integer', 'null'] }
      expect(format(schema)).to eq("{ 'type' => %w[integer null] }")
    end

    it 'respects the indent argument' do
      result = format({ first_name: 'Alex', last_name: 'Hamilton' }, indent: 4, width: 30)
      expect(result).to eq("    {\n      first_name: 'Alex',\n      last_name: 'Hamilton'\n    }")
    end

    it 'uses hash rocket for symbol keys that are not valid identifiers' do
      expect(format({ :'foo bar' => 1 })).to eq(%q[{ :"foo bar" => 1 }])
    end
  end

  describe 'a realistic JSON Schema' do
    it 'produces rubocop-friendly output' do
      schema = {
        '$schema' => 'http://json-schema.org/draft-07/schema#',
        '$id' => 'http://example.com/v4/thing.json',
        'title' => 'thing',
        'type' => 'object',
        'properties' => {
          'genres' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
          'web_url' => { 'type' => 'string' },
          'average_rating' => { 'type' => %w[number null] }
        },
        'required' => %w[genres web_url],
        'additionalProperties' => false
      }
      result = format(schema, width: 80)
      expect(result).to eq(<<~OUT.chomp)
        {
          '$schema' => 'http://json-schema.org/draft-07/schema#',
          '$id' => 'http://example.com/v4/thing.json',
          'title' => 'thing',
          'type' => 'object',
          'properties' => {
            'genres' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
            'web_url' => { 'type' => 'string' },
            'average_rating' => { 'type' => %w[number null] }
          },
          'required' => %w[genres web_url],
          'additionalProperties' => false
        }
      OUT
    end
  end
end
