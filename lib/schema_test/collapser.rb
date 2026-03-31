module SchemaTest
  class Collapser
    def initialize(contents)
      @lines = contents.split("\n")
    end

    def output
      result = []
      i = 0
      while i < @lines.length
        line = @lines[i]

        # Skip rubocop:disable line immediately before an EXPANDED block
        if line.match?(/#{DISABLE_RUBOCOP_COMMENT}/) &&
            i + 1 < @lines.length && @lines[i + 1].match?(/#{OPENING_COMMENT}/)
          i += 1
          next
        end

        if line =~ /\A(\s*)(\w+)\(\s*#{OPENING_COMMENT}/
          indent = $1
          method_name = $2

          # Next line is the json variable
          json_var = @lines[i + 1].strip.sub(/,\z/, '')

          # Gather remaining content lines until closing marker
          content_lines = []
          j = i + 2
          while j < @lines.length && !@lines[j].match?(/#{CLOSING_COMMENT}/)
            content_lines << @lines[j]
            j += 1
          end
          end_index = j

          # Extract name and version from the content
          joined = content_lines.map(&:strip).join(' ')
          name = joined.match(/:(\w+),/)[1]
          version_match = joined.match(/:version\s*=>\s*([^,}]+)/)
          version = version_match[1].strip

          result << "#{indent}#{method_name}(#{json_var}, :#{name}, version: #{version})"

          # Skip rubocop:enable line immediately after END EXPANDED
          i = end_index + 1
          if i < @lines.length && @lines[i].match?(/#{ENABLE_RUBOCOP_COMMENT}/)
            i += 1
          end
        else
          result << line
          i += 1
        end
      end

      result.join("\n") + "\n"
    end
  end
end
