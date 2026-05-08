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

    SchemaCall = Struct.new(:line_index, :assertion_method, :name, :version, :location, :expected_schema) do
      def self.from(item)
        item.is_a?(SchemaCall) ? item : new(*item)
      end
    end

    def output
      current_offset = 0
      sorted_calls.each do |call|
        current_offset += rewrite_call(call, current_offset)
      end
      "#{lines.compact.join("\n")}\n"
    end

    private

    attr_reader :lines, :line_indexes_with_schemas, :disable_rubocop

    def sorted_calls
      line_indexes_with_schemas.map { |item| SchemaCall.from(item) }.sort_by(&:line_index)
    end

    # Replaces the lines for one schema call and returns the net change in
    # line count (negative if the result is shorter than the original block).
    def rewrite_call(call, current_offset)
      start_index = call.line_index + current_offset
      offset_delta = 0
      if lines[start_index - 1]&.match?(/#{DISABLE_RUBOCOP_COMMENT}/)
        lines.delete_at(start_index - 1)
        start_index -= 1
        offset_delta -= 2
      end

      end_index, json_variable_name = locate_existing_block(start_index)
      original_length = end_index - start_index
      start_indent = lines[start_index].match(/\A(\s*)/)[0].length
      (original_length + 1).times { lines.delete_at(start_index) }

      method_string = build_method_string(call, json_variable_name, start_indent)
      method_string.reverse_each { |line| lines.insert(start_index, line) }

      offset_delta + method_string.count - original_length - 1
    end

    def locate_existing_block(start_index)
      if lines[start_index] =~ /#{OPENING_COMMENT}/
        end_index = start_index + lines[start_index..].find_index { |line| line =~ /#{CLOSING_COMMENT}\s*\z/ }
        lines.delete_at(end_index + 1) if lines[end_index + 1]&.match?(/#{ENABLE_RUBOCOP_COMMENT}/)
        json_variable_name = lines[start_index + 1].strip.gsub(/,\z/, '')
      else
        end_index = start_index
        json_variable_name = lines[start_index].match(/\(([^,]+)/)[1]
      end
      [end_index, json_variable_name]
    end

    def build_method_string(call, json_variable_name, start_indent)
      pad = ' ' * start_indent
      [
        disable_rubocop ? pad + DISABLE_RUBOCOP_COMMENT : nil,
        "#{pad}#{call.assertion_method}( #{OPENING_COMMENT} from #{call.location}",
        *expanded_argument_lines(call, json_variable_name, start_indent),
        "#{pad}) #{CLOSING_COMMENT}",
        disable_rubocop ? pad + ENABLE_RUBOCOP_COMMENT : nil
      ].compact
    end

    def expanded_argument_lines(call, json_variable_name, start_indent)
      inner_indent = start_indent + 2
      name_lines = SchemaTest::PrettyPrinter.format(call.name, indent: inner_indent).split("\n")
      name_lines[-1] = "#{name_lines[-1]},"
      options_lines = SchemaTest::PrettyPrinter.format(
        { version: call.version, schema: call.expected_schema },
        indent: inner_indent
      ).split("\n")
      ["#{' ' * inner_indent}#{json_variable_name},", *name_lines, *options_lines]
    end
  end
end
