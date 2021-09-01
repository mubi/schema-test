require "bundler/setup"
require "schema_test"
require "byebug"

RSpec::Matchers.define :match_schema do |expected|
  match do |actual|
    @differences = []
    if actual.name != expected.name
      @differences << %(actual name was '#{expected.name}' and not '#{actual.name}')
    end
    if actual.version != expected.version
      @differences << %(actual version was #{expected.version} and not #{actual.version})
    end
    missing_keys = actual.properties.keys - expected.properties.keys
    extra_keys = expected.properties.keys - actual.properties.keys
    if missing_keys.any?
      @differences << %(some keys were missing: %p) % missing_keys
    end
    if extra_keys.any?
      @differences << %(some keys were not expected: %p) % extra_keys
    end
    actual.properties.each do |name, expected_property|
      expected_property = expected.properties[name]
      if expected_property != expected_property
        @differences << %(#{name} property did not match: #{expected_property.inspect} vs #{expected_property.inspect})
      end
    end

    @differences.empty?
  end

  failure_message do
    @differences.join("\n")
  end

  failure_message_when_negated do
    'expected schema not to match, but it did'
  end
end

RSpec::Matchers.define :validate_json do |actual_json|
  match do |definition|
    @errors = SchemaTest.validate_json(actual_json, definition)
    @errors.empty?
  end

  match_when_negated do |definition|
    @errors = SchemaTest.validate_json(actual_json, definition)
    if @because
      @errors.include?(@because)
    else
      !@errors.empty?
    end
  end

  chain :because, :because

  failure_message do |actual|
    "expected JSON to validate, but got errors:\n#{@errors.join("\n")}"
  end

  failure_message_when_negated do |actual|
    if @because
      "expected errors to contain #{@because.inspect}, but they were #{@errors.join("\n")}"
    else
      "expected JSON not to validate, but it did"
    end
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    SchemaTest.reset!
  end
end
