module SchemaTest
  # Rewrites `assert_valid_json_for_schema` calls in test files so that
  # they carry an up-to-date `fingerprint:` argument matching the
  # compiled schema. This means a schema change shows up as a diff in
  # the test files themselves, pointing at exactly which API endpoints
  # changed, and lets the assertion verify the fingerprint at runtime.
  class FingerprintRewriter
    FINGERPRINT_ARGUMENT = /fingerprint:\s*("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^\s,)]+)/

    def initialize(contents, line_indexes_with_fingerprints)
      @lines = contents.split("\n")
      @line_indexes_with_fingerprints = line_indexes_with_fingerprints
    end

    def output
      @line_indexes_with_fingerprints.each do |line_index, fingerprint|
        line = @lines[line_index]
        next unless line
        @lines[line_index] = annotate(line, fingerprint)
      end
      @lines.join("\n") + "\n"
    end

    private

    def annotate(line, fingerprint)
      if line =~ FINGERPRINT_ARGUMENT
        line.sub(FINGERPRINT_ARGUMENT, %(fingerprint: "#{fingerprint}"))
      else
        index = line.rindex(')')
        return line unless index
        %(#{line[0...index]}, fingerprint: "#{fingerprint}"#{line[index..-1]})
      end
    end
  end
end
