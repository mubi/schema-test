require 'json'
require 'json_schemer'
require 'shellwords'

module SchemaTest
  class Validator
    def initialize(json_or_data)
      @data = case json_or_data
              when Hash, Array
                JSON.parse(json_or_data.to_json)
              when String
                JSON.parse(json_or_data)
              else
                json_or_data
              end
    end

    def validate_using_definition(definition)
      validate_using_json_schema(definition.as_json_schema)
    end

    def validate_using_json_schema(schema)
      json_schema = JSONSchemer.schema(schema)
      errors = json_schema.validate(@data).to_a
      convert_json_schemer_errors(errors)
    end

    private

    def convert_json_schemer_errors(errors)
      errors.map { |error| convert_json_schemer_error(error) }
    end

    def convert_json_schemer_error(error)
      if error['schema_pointer'] == '/additionalProperties'
        additional_key = error['data_pointer']
        "object contains the extra key: #{additional_key}"
      else
        message = case error['type']
                  when 'format'
                    "format should be #{error['schema']['format']}"
                  when 'required'
                    "missing some required attributes"
                  else
                    if error['type'] == 'type'
                      "type should be one of #{error['schema']['type'].inspect}"
                    else
                      "type should be #{error['type']}"
                    end
                  end
        "value at #{error['data_pointer']} (#{error['data'].inspect}) failed validation: #{message}"
      end
    end
  end
end
