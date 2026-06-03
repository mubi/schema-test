module SchemaTest
  # Rewrites `assert_valid_json_for_schema` calls in test files so that
  # they carry an up-to-date `fingerprint:` argument matching the
  # compiled schema. This means a schema change shows up as a diff in
  # the test files themselves, pointing at exactly which API endpoints
  # changed, and lets the assertion verify the fingerprint at runtime.
  #
  # The call site reported at runtime is the line the call *starts* on,
  # which for a multi-line call is the line with the opening paren. The
  # rewriter therefore scans forward to find the matching closing paren
  # before inserting or replacing the argument.
  class FingerprintRewriter
    FINGERPRINT_ARGUMENT = /fingerprint:\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\s,)]+)/

    def initialize(contents, line_indexes_with_fingerprints)
      @lines = contents.split("\n")
      @line_indexes_with_fingerprints = line_indexes_with_fingerprints
    end

    def output
      @line_indexes_with_fingerprints.each do |start_index, fingerprint|
        next unless @lines[start_index]
        annotate_call(start_index, fingerprint)
      end
      @lines.join("\n") + "\n"
    end

    private

    def annotate_call(start_index, fingerprint)
      close = find_closing_paren(start_index)
      return unless close
      end_index, paren_column = close

      # If the call already carries a fingerprint argument, replace it.
      (start_index..end_index).each do |index|
        if @lines[index] =~ FINGERPRINT_ARGUMENT
          @lines[index] = @lines[index].sub(FINGERPRINT_ARGUMENT, "fingerprint: '#{fingerprint}'")
          return
        end
      end

      argument = "fingerprint: '#{fingerprint}'"
      close_line = @lines[end_index]
      before_paren = close_line[0...paren_column]

      if before_paren.strip.empty?
        # The closing paren is on its own line; append the argument to the
        # last argument line so we don't leave a leading comma dangling.
        insert_index = (start_index...end_index).to_a.reverse.find { |index| !@lines[index].strip.empty? } || start_index
        @lines[insert_index] = "#{@lines[insert_index].sub(/,\s*\z/, '')}, #{argument}"
      else
        @lines[end_index] = "#{before_paren.sub(/,\s*\z/, '')}, #{argument}#{close_line[paren_column..-1]}"
      end
    end

    # Finds the closing paren matching the first opening paren at or after
    # the start line, returning [line_index, column] or nil. Skips parens
    # inside string literals and trailing comments.
    def find_closing_paren(start_index)
      depth = 0
      started = false
      (start_index...@lines.length).each do |line_index|
        line = @lines[line_index]
        string_delimiter = nil
        column = 0
        while column < line.length
          char = line[column]
          if string_delimiter
            if char == '\\'
              column += 2
              next
            elsif char == string_delimiter
              string_delimiter = nil
            end
          elsif char == '"' || char == "'"
            string_delimiter = char
          elsif char == '#'
            break
          elsif char == '('
            depth += 1
            started = true
          elsif char == ')'
            depth -= 1
            return [line_index, column] if started && depth.zero?
          end
          column += 1
        end
      end
      nil
    end
  end
end
