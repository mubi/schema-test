module SchemaTest
  class Configuration
    # The domain is used to contstruct the `$id` part of the generated
    # JSON-Schema definitions. This can be set to anything you like really.
    attr_accessor :domain

    # This should be an array or one or more paths. All ruby files under these
    # paths will all be loaded when `SchemaTest.setup!` is called. You can nest
    # files in as many subdirectories are you like.
    attr_accessor :definition_paths

    # Set to true in order to disable running rubocop on the expanded schemas,
    # as the Ruby PP output does not conform to rubocop's standards.
    attr_accessor :disable_rubocop

    # Set to true to use pre-compiled JSON schema files for validation
    # instead of inlining expanded schemas into test files.
    attr_accessor :compiled

    def initialize
      @domain = 'example.com'
      @definition_paths = []
      @disable_rubocop = false
      @compiled = false
    end
  end
end
