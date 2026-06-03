require 'spec_helper'

RSpec.describe 'SchemaTest.schema_fingerprint' do
  it 'is stable for the same schema' do
    schema = { 'title' => 'film', 'properties' => { 'name' => { 'type' => 'string' } } }
    expect(SchemaTest.schema_fingerprint(schema)).to eq SchemaTest.schema_fingerprint(schema)
  end

  it 'changes when the schema changes' do
    one = { 'title' => 'film', 'properties' => { 'name' => { 'type' => 'string' } } }
    two = { 'title' => 'film', 'properties' => { 'name' => { 'type' => 'integer' } } }
    expect(SchemaTest.schema_fingerprint(one)).not_to eq SchemaTest.schema_fingerprint(two)
  end

  it 'is a hex SHA-256 digest' do
    fingerprint = SchemaTest.schema_fingerprint({ 'title' => 'film' })
    expect(fingerprint).to match(/\A[0-9a-f]{64}\z/)
  end
end

RSpec.describe SchemaTest::FingerprintRewriter do
  def rewrite(contents, fingerprints)
    described_class.new(contents, fingerprints).output
  end

  it 'inserts a fingerprint argument into an assertion that has none' do
    contents = "assert_valid_json_for_schema(json, :film, version: 1)\n"
    output = rewrite(contents, { 0 => 'abc123' })
    expect(output).to eq %(assert_valid_json_for_schema(json, :film, version: 1, fingerprint: "abc123")\n)
  end

  it 'replaces an existing fingerprint argument' do
    contents = %(assert_valid_json_for_schema(json, :film, version: 1, fingerprint: "old")\n)
    output = rewrite(contents, { 0 => 'new' })
    expect(output).to eq %(assert_valid_json_for_schema(json, :film, version: 1, fingerprint: "new")\n)
  end

  it 'inserts before the closing paren of the call, not a nested one' do
    contents = "assert_valid_json_for_schema(JSON.parse(body), :film, version: 1)\n"
    output = rewrite(contents, { 0 => 'abc' })
    expect(output).to eq %(assert_valid_json_for_schema(JSON.parse(body), :film, version: 1, fingerprint: "abc")\n)
  end

  it 'preserves a trailing comment after the call' do
    contents = "assert_valid_json_for_schema(json, :film) # a note\n"
    output = rewrite(contents, { 0 => 'abc' })
    expect(output).to eq %(assert_valid_json_for_schema(json, :film, fingerprint: "abc") # a note\n)
  end

  it 'only rewrites the targeted lines' do
    contents = "line one\nassert_valid_json_for_schema(json, :film)\nline three\n"
    output = rewrite(contents, { 1 => 'abc' })
    expect(output).to eq "line one\nassert_valid_json_for_schema(json, :film, fingerprint: \"abc\")\nline three\n"
  end

  it 'inserts into a multi-line call where the start line has no closing paren' do
    contents = <<~RUBY
      assert_valid_json_for_schema(
        json,
        :film,
        version: 1
      )
    RUBY
    output = rewrite(contents, { 0 => 'abc' })
    expect(output).to eq <<~RUBY
      assert_valid_json_for_schema(
        json,
        :film,
        version: 1, fingerprint: "abc"
      )
    RUBY
  end

  it 'replaces an existing fingerprint in a multi-line call' do
    contents = <<~RUBY
      assert_valid_json_for_schema(
        json,
        :film,
        version: 1,
        fingerprint: "old"
      )
    RUBY
    output = rewrite(contents, { 0 => 'new' })
    expect(output).to eq <<~RUBY
      assert_valid_json_for_schema(
        json,
        :film,
        version: 1,
        fingerprint: "new"
      )
    RUBY
  end

  it 'handles a trailing comma on the last argument of a multi-line call' do
    contents = <<~RUBY
      assert_valid_json_for_schema(
        json,
        :film,
        version: 1,
      )
    RUBY
    output = rewrite(contents, { 0 => 'abc' })
    expect(output).to eq <<~RUBY
      assert_valid_json_for_schema(
        json,
        :film,
        version: 1, fingerprint: "abc"
      )
    RUBY
  end
end
