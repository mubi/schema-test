require 'schema_test/pretty_printer'

module SchemaTest
  OPENING_COMMENT = '# EXPANDED'.freeze
  CLOSING_COMMENT = '# END EXPANDED'.freeze

  DISABLE_RUBOCOP_COMMENT = '# rubocop:disable all'.freeze
  ENABLE_RUBOCOP_COMMENT = '# rubocop:enable all'.freeze

  class Rewriter
    def initialize(contents, line_indexes_with_schemas, options: {})
      @lines = contents.split("\n")
      @line_indexes_with_schemas = line_indexes_with_schemas

      @disable_rubocop = options.fetch(:disable_rubocop, false)
    end

    def output
      current_offset = 0
      line_indexes_with_schemas.sort_by { |(line, _)| line }.each do |index, method, name, version, location, expected_schema|
        start_index = index + current_offset
        if lines[start_index - 1].match?(/#{DISABLE_RUBOCOP_COMMENT}/)
          lines.delete_at(start_index - 1)
          start_index -= 1
          current_offset -= 2
        end

        if lines[start_index] =~ /#{OPENING_COMMENT}/
          end_index = start_index + lines[start_index..].find_index { |line| line =~ /#{CLOSING_COMMENT}\s*\z/ }
          lines.delete_at(end_index + 1) if lines[end_index + 1]&.match?(/#{ENABLE_RUBOCOP_COMMENT}/)
          json_variable_name = lines[start_index + 1].strip.gsub(/,\z/, '')
        else
          end_index = start_index
          json_variable_name = lines[start_index].match(/\(([^,]+)/)[1]
        end

        original_method_definition_length = end_index - start_index
        start_indent = lines[start_index].match(/\A(\s*)/)[0].length
        (end_index - start_index + 1).times { |_i| lines.delete_at(start_index) }

        inner_indent = start_indent + 2
        name_lines = SchemaTest::PrettyPrinter.format(name, indent: inner_indent).split("\n")
        name_lines[-1] = "#{name_lines[-1]},"
        options_lines = SchemaTest::PrettyPrinter.format(
          { version: version, schema: expected_schema },
          indent: inner_indent
        ).split("\n")

        expanded_schema_lines = ["#{' ' * inner_indent}#{json_variable_name},", *name_lines, *options_lines]

        method_string = [
          disable_rubocop ? (' ' * start_indent) + DISABLE_RUBOCOP_COMMENT : nil,
          (' ' * start_indent) + method.to_s + "( #{OPENING_COMMENT} from #{location}",
          *expanded_schema_lines,
          (' ' * start_indent) + ") #{CLOSING_COMMENT}",
          disable_rubocop ? (' ' * start_indent) + ENABLE_RUBOCOP_COMMENT : nil
        ].compact

        method_string.reverse.each { |line| lines.insert(start_index, line) }

        current_offset += method_string.count - original_method_definition_length - 1
      end

      "#{lines.compact.join("\n")}\n"
    end

    private

    attr_reader :lines, :line_indexes_with_schemas, :disable_rubocop
  end
end
