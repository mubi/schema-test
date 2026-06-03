require 'spec_helper'
require 'schema_test/minitest'
require 'tmpdir'
require 'fileutils'
require 'json'

# Exercises the real `assert_valid_json_for_schema` assertion in compiled
# mode, end to end: a definition is compiled to disk, the assertion loads
# the compiled schema, checks the fingerprint, and (locally) rewrites the
# test file to carry an up-to-date `fingerprint:` argument.
RSpec.describe 'compiled mode assertions' do
  let(:definition_path) { Dir.mktmpdir }

  # A stand-in for a Minitest::Test instance: it mixes in the assertion
  # module and provides the `assert`/`flunk` hooks the module relies on.
  let(:harness) do
    Class.new do
      include SchemaTest::Minitest

      def assert(value, message = nil)
        raise SchemaTest::Error, (message || 'assertion failed') unless value
      end

      def flunk(message = nil)
        raise SchemaTest::Error, "flunk: #{message}"
      end
    end.new
  end

  before do
    # The rewrite queue/hook live in module class variables; reset them so
    # examples don't leak into each other.
    SchemaTest::Minitest.class_variable_set(:@@__schema_fingerprints, {})
    SchemaTest::Minitest.class_variable_set(:@@__schema_fingerprint_hook_installed, false)

    SchemaTest.configure do |config|
      config.domain = 'example.com'
      config.definition_paths << definition_path
      config.compiled = true
    end

    SchemaTest::Definition.new(:widget, version: 1, location: 'api/widget.rb:1', properties: [
      SchemaTest::Property::String.new(:name)
    ])
    SchemaTest.compile!
  end

  after do
    FileUtils.remove_entry(definition_path)
  end

  let(:expected_fingerprint) do
    SchemaTest.schema_fingerprint(SchemaTest.load_compiled_schema(:widget, version: 1))
  end

  # Evaluates the test file so that `caller` inside the assertion resolves
  # to the file/line we wrote, exactly as it would in a real test run.
  # `at_exit` is stubbed so the deferred rewrite can be triggered inline
  # (and returned) instead of running when the rspec process exits.
  def run_test_file(contents)
    test_file = File.join(definition_path, 'widget_test.rb')
    File.write(test_file, contents)

    deferred_rewrite = nil
    allow(harness).to receive(:at_exit) { |&block| deferred_rewrite = block }

    json = { 'name' => 'thing' }
    eval(File.read(test_file), binding, test_file) # rubocop:disable Security/Eval

    [test_file, deferred_rewrite]
  end

  def without_ci
    original = ENV['CI']
    ENV.delete('CI')
    yield
  ensure
    original.nil? ? ENV.delete('CI') : ENV['CI'] = original
  end

  def with_ci
    original = ENV['CI']
    ENV['CI'] = '1'
    yield
  ensure
    original.nil? ? ENV.delete('CI') : ENV['CI'] = original
  end

  it 'rewrites the test file with the compiled schema fingerprint when it is missing' do
    without_ci do
      test_file, deferred_rewrite = run_test_file(<<~RUBY)
        # widget endpoint
        harness.assert_valid_json_for_schema(json, :widget, version: 1)
      RUBY

      expect(deferred_rewrite).not_to be_nil
      deferred_rewrite.call

      expect(File.read(test_file)).to eq(<<~RUBY)
        # widget endpoint
        harness.assert_valid_json_for_schema(json, :widget, version: 1, fingerprint: '#{expected_fingerprint}')
      RUBY
    end
  end

  it 'leaves the test file untouched when the fingerprint already matches' do
    without_ci do
      contents = <<~RUBY
        # widget endpoint
        harness.assert_valid_json_for_schema(json, :widget, version: 1, fingerprint: '#{expected_fingerprint}')
      RUBY

      test_file, deferred_rewrite = run_test_file(contents)

      expect(deferred_rewrite).to be_nil
      expect(File.read(test_file)).to eq(contents)
    end
  end

  it 'updates a stale fingerprint in the test file' do
    without_ci do
      test_file, deferred_rewrite = run_test_file(<<~RUBY)
        harness.assert_valid_json_for_schema(json, :widget, version: 1, fingerprint: 'stalevalue00')
      RUBY

      deferred_rewrite.call

      expect(File.read(test_file)).to eq(<<~RUBY)
        harness.assert_valid_json_for_schema(json, :widget, version: 1, fingerprint: '#{expected_fingerprint}')
      RUBY
    end
  end

  it 'flunks instead of rewriting when the fingerprint is stale in CI' do
    with_ci do
      expect {
        run_test_file(<<~RUBY)
          harness.assert_valid_json_for_schema(json, :widget, version: 1, fingerprint: 'stalevalue00')
        RUBY
      }.to raise_error(SchemaTest::Error, /flunk: Schema fingerprint mismatch/)
    end
  end

  it 'fails the assertion when the JSON does not match the compiled schema' do
    without_ci do
      test_file = File.join(definition_path, 'widget_test.rb')
      File.write(test_file, "harness.assert_valid_json_for_schema(bad_json, :widget, version: 1, fingerprint: '#{expected_fingerprint}')\n")
      allow(harness).to receive(:at_exit)

      bad_json = { 'name' => 123 }
      expect {
        eval(File.read(test_file), binding, test_file) # rubocop:disable Security/Eval
      }.to raise_error(SchemaTest::Error, /JSON did not pass schema/)
    end
  end
end
