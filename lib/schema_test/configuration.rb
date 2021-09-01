module SchemaTest
  class Configuration
    # The domain is used to contstruct the `$id` part of the generated
    # JSON-Schema definitions. This can be set to anything you like really.
    attr_accessor :domain

    # This should be an array or one or more paths. All ruby files under these
    # paths will all be loaded when `SchemaTest.setup!` is called. You can nest
    # files in as many subdirectories are you like.
    attr_accessor :definition_paths

    def initialize
      @domain = 'example.com'
      @definition_paths = []
    end
  end
end
