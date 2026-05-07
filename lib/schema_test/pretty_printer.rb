module SchemaTest
  class PrettyPrinter
    DEFAULT_WIDTH = 100

    def self.format(value, indent: 0, width: DEFAULT_WIDTH)
      new(width).format(value, indent).join("\n")
    end

    def initialize(width)
      @width = width
    end

    def format(value, indent)
      inline = format_inline(value)
      if indent + inline.length <= @width
        [(' ' * indent) + inline]
      else
        format_multiline(value, indent)
      end
    end

    private

    def format_inline(value)
      case value
      when Hash
        return '{}' if value.empty?
        '{ ' + value.map { |k, v| format_key(k) + format_inline(v) }.join(', ') + ' }'
      when Array
        return format_word_array(value) if word_array?(value)
        return format_symbol_array(value) if symbol_array?(value)
        '[' + value.map { |e| format_inline(e) }.join(', ') + ']'
      when String
        format_string(value)
      when Symbol
        format_symbol(value)
      when nil
        'nil'
      when true, false
        value.to_s
      when Numeric
        value.inspect
      else
        value.inspect
      end
    end

    def format_multiline(value, indent)
      pad = ' ' * indent
      inner = indent + 2
      case value
      when Hash
        items = value.to_a
        item_lines = items.each_with_index.flat_map do |(k, v), i|
          lines = format_pair(k, v, inner)
          lines[-1] = lines[-1] + ',' unless i == items.size - 1
          lines
        end
        [pad + '{'] + item_lines + [pad + '}']
      when Array
        item_lines = value.each_with_index.flat_map do |e, i|
          lines = format(e, inner)
          lines[-1] = lines[-1] + ',' unless i == value.size - 1
          lines
        end
        [pad + '['] + item_lines + [pad + ']']
      else
        [pad + format_inline(value)]
      end
    end

    def format_pair(key, value, indent)
      pad = ' ' * indent
      key_str = format_key(key)
      inline_value = format_inline(value)
      candidate = pad + key_str + inline_value
      return [candidate] if candidate.length <= @width

      case value
      when Hash
        return [pad + key_str + '{}'] if value.empty?
        inner = indent + 2
        items = value.to_a
        item_lines = items.each_with_index.flat_map do |(k, v), i|
          lines = format_pair(k, v, inner)
          lines[-1] = lines[-1] + ',' unless i == items.size - 1
          lines
        end
        [pad + key_str + '{'] + item_lines + [pad + '}']
      when Array
        return [pad + key_str + '[]'] if value.empty?
        inner = indent + 2
        item_lines = value.each_with_index.flat_map do |e, i|
          lines = format(e, inner)
          lines[-1] = lines[-1] + ',' unless i == value.size - 1
          lines
        end
        [pad + key_str + '['] + item_lines + [pad + ']']
      else
        [candidate]
      end
    end

    def format_key(key)
      if key.is_a?(Symbol) && key.to_s.match?(/\A[A-Za-z_][A-Za-z0-9_]*[!?=]?\z/)
        "#{key}: "
      else
        format_inline(key) + ' => '
      end
    end

    def format_string(string)
      if string.include?("'") || string.include?('\\')
        string.inspect
      else
        "'#{string}'"
      end
    end

    BAREWORD = /\A[A-Za-z_][A-Za-z0-9_]*\z/.freeze

    def format_symbol(symbol)
      symbol.to_s.match?(BAREWORD) ? ":#{symbol}" : symbol.inspect
    end

    def word_array?(array)
      array.size >= 2 && array.all? { |e| e.is_a?(String) && e.match?(BAREWORD) }
    end

    def symbol_array?(array)
      array.size >= 2 && array.all? { |e| e.is_a?(Symbol) && e.to_s.match?(BAREWORD) }
    end

    def format_word_array(array)
      "%w[#{array.join(' ')}]"
    end

    def format_symbol_array(array)
      "%i[#{array.join(' ')}]"
    end
  end
end
