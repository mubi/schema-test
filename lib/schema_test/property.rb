module SchemaTest
  class Property
    attr_reader :name, :type, :description, :optional

    def initialize(name, type, description=nil)
      @name = name
      @type = type
      @description = description
      @optional = false
    end

    def as_structure(_=nil)
      if @optional
        { name => nil }
      else
        name
      end
    end

    def as_json_schema
      json_schema = { 'type' => json_schema_type }
      json_schema['description'] = description if description
      json_schema['format'] = json_schema_format if json_schema_format
      { name.to_s => json_schema }
    end

    def ==(other)
      return false unless other.is_a?(SchemaTest::Property)

      name == other.name &&
        type == other.type &&
        description == other.description &&
        optional == other.optional
    end

    def optional?
      optional
    end

    def optional!
      @optional = true
    end

    def json_schema_type
      @type.to_s
    end

    def json_schema_format
      nil
    end

    class Boolean < SchemaTest::Property
      def initialize(name, description=nil)
        super(name, :boolean, description)
      end
    end

    class Integer < SchemaTest::Property
      def initialize(name, description=nil)
        super(name, :integer, description)
      end
    end

    class Float < SchemaTest::Property
      def initialize(name, description=nil)
        super(name, :float, description)
      end

      def json_schema_type
        'number'
      end
    end

    class String < SchemaTest::Property
      def initialize(name, description=nil)
        super(name, :string, description)
      end
    end

    class DateTime < SchemaTest::Property
      def initialize(name, description=nil)
        super(name, :datetime, description)
      end

      def json_schema_type
        'string'
      end

      def json_schema_format
        'date-time'
      end
    end

    class Uri < SchemaTest::Property::String
      def json_schema_format
        'uri'
      end
    end

    class SchemaTest::Property::Object < SchemaTest::Property
      attr_reader :version

      def initialize(name, description: nil, version: nil, from: nil, properties: nil, &block)
        @name = name
        @description = description
        @version = version
        @specific_properties = properties
        @properties = {}
        @from = from
        instance_eval(&block) if block_given?
      end

      def properties
        resolve
        @properties
      end

      def ==(other)
        super && properties.all? { |name, property| property == other.properties[name] }
      end

      def resolve
        if @from
          @properties.merge!(@from.properties)
          @from = nil
        end
        if @specific_properties
          @specific_properties.each { |p| define_property(p) }
          @specific_properties = nil
        end
        self
      end

      SHORTHAND_ATTRIBUTES = {
        id: :integer,
        slug: :string,
        updated_at: :datetime,
        created_at: :datetime
      }

      SHORTHAND_ATTRIBUTES.each do |name, type|
        define_method(name) { send(type, name) }
      end

      TYPES = {
        boolean: SchemaTest::Property::Boolean,
        integer: SchemaTest::Property::Integer,
        float: SchemaTest::Property::Float,
        string: SchemaTest::Property::String,
        datetime: SchemaTest::Property::DateTime,
        url: SchemaTest::Property::Uri,
        html: SchemaTest::Property::String
      }

      TYPES.each do |method_name, type_class|
        define_method(method_name) do |name, desc: nil|
          define_property(type_class.new(name, desc))
        end
      end

      def array(name, of: nil, desc: nil, &block)
        define_property(SchemaTest::Property::Array.new(name, of, desc, &block))
      end

      def object(name, desc: nil, as: name, version: nil, &block)
        inferred_version = version || @version
        if block_given?
          define_property(SchemaTest::Property::Object.new(as, description: desc, version: inferred_version, &block))
        else
          define_property(SchemaTest::Property::Object.new(as, description: desc, version: inferred_version, from: lookup_object(name, inferred_version)))
        end
      end

      def as_json_schema(include_root=true)
        property_values = properties.values
        required_property_names = property_values.reject(&:optional?).map(&:name).map(&:to_s)
        schema = {
          'type' => json_schema_type,
          'properties' => property_values.inject({}) { |a,p| a.merge(p.as_json_schema) },
          'required' => required_property_names,
          'additionalProperties' => false
        }
        if include_root
          { name.to_s => schema }
        else
          schema
        end
      end

      def as_structure(include_root=true)
        if include_root
          { name => properties.values.map(&:as_structure) }
        else
          properties.values.map(&:as_structure)
        end
      end

      def json_schema_type
        'object'
      end

      private

      def define_property(attribute)
        @properties[attribute.name] = attribute
      end

      def lookup_object(name, version)
        UnresolvedProperty.new(name, version: version)
      end
    end

    class UnresolvedProperty < SchemaTest::Property::Object
      def resolve
        SchemaTest::Definition.find!(name, version)
      end

      def ==(other)
        resolve == other
      end

      def properties
        resolve.properties
      end

      def as_structure(*args)
        resolve.as_structure(*args)
      end
    end

    class AnonymousObject < SchemaTest::Property::Object
      def initialize(properties: nil, &block)
        super(nil, properties: properties, &block)
      end

      def as_structure(_=nil)
        super(false)
      end
    end

    class Array < SchemaTest::Property
      attr_reader :item_type

      def initialize(name, of=nil, description=nil, &block)
        super(name, :array, description)
        if block_given?
          @item_type = AnonymousObject.new(&block)
        else
          @item_type = of
        end
        # @items = { type: @item_type }
      end

      def ==(other)
        super && @item_type == other.item_type
      end

      def as_structure(_=nil)
        if @item_type.is_a?(SchemaTest::Property)
          { name => @item_type.as_structure(false) }
        else
          { name => [] }
        end
      end

      def as_json_schema
        super.tap do |json_schema|
          item_schema = @item_type.is_a?(SchemaTest::Property) ? @item_type.as_json_schema(false) : { 'type' => @item_type.to_s }
          json_schema[name.to_s]['items'] = item_schema
        end
      end
    end
  end
end
