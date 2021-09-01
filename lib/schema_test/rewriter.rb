require 'pp'

module SchemaTest
  OPENING_COMMENT = '# EXPANDED'.freeze
  CLOSING_COMMENT = '# END EXPANDED'.freeze

  class Rewriter
    def initialize(contents, line_indexes_with_schemas)
      @lines = contents.split("\n")
      @line_indexes_with_schemas = line_indexes_with_schemas
    end

    def output
      current_offset = 0
      line_indexes_with_schemas.sort_by { |(line,_)| line }.each do |index, method, name, version, expected_schema|
        start_index = index + current_offset
        if lines[start_index] =~ /#{OPENING_COMMENT}\s*\z/
          end_index = start_index + lines[start_index..-1].find_index { |line| line =~ /#{CLOSING_COMMENT}\s*\z/ }
          json_variable_name = lines[start_index + 1].strip.gsub(/,\z/, '')
        else
          end_index = start_index
          json_variable_name = lines[start_index].match(/\(([^,]+)/)[1]
        end
        start_indent = lines[start_index].match(/\A(\s*)/)[0].length
        (end_index - start_index + 1).times { |i| lines.delete_at(start_index) }

        output = StringIO.new
        PP.pp([name, version: version, schema: expected_schema], output)
        output.rewind
        expanded_schema_lines = output.read.strip.gsub(/\A\[/, '').gsub(/\]\z/, '').split("\n")
        expanded_schema_lines.unshift(json_variable_name + ',')

        method_string = [
          (' ' * start_indent) + method.to_s + "( #{OPENING_COMMENT}",
          *expanded_schema_lines.map { |line| (' ' * (start_indent + 2)) + line },
          (' ' * start_indent) + ") #{CLOSING_COMMENT}"
        ]

        method_string.reverse.each { |line| lines.insert(start_index, line) }

        current_offset += method_string.count - 1
      end

      lines.compact.join("\n") + "\n"
    end

    private

    attr_reader :lines, :line_indexes_with_schemas
  end
end
