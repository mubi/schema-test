# SchemaTest

This gem provides a convenient and flexible way for specifying and testing schema definitions for JSON API response. The mean features are:

* A simple Ruby-based DSL for capturing JSON objects, including property names, types, and metadata like descriptions
* Simple ways to _version_ those schemas, and specify new versions efficiently
* Mechanisms to evaluate a given JSON blob against a schema to verify it matches
* Mechanisms to write tests for multiple API versions that strike a good balance between efficiency of specifiation vs avoiding unintentional impacts to endpoints. I'll explain that later.

## How & why

This gem provides a way to define JSON Schema objects using a simple Ruby DSL, in a way that allows other schemas to be easily composed of existing ones:

``` ruby

# Define a simple user schema
SchemaTest.define :user do
  id
  string :name
  url :avatar_url
end

# Define a new comment schema
SchemaTest.define :comment do
  string :body

  # re-use the user schema, but give the object a different name
  object :user, as: :author
end
```

This lets you minimise duplication between your schema definitions in a convenient way. And we can then use the generated JSON-Schema data (see below) to validate our app's generated responses against this.

But JSON-Schema already lets you compose schemas, right? What's the point of this?

### API versioning

Let's imagine we have some test for our comments API output, something like (pseudocode):

``` ruby
get :comment

assert_schema_matches response.body, schema_for(:comment)
```

Then, some time later, we create a new version of our API, and some of the serialised objects have changes - new fields, removed fields, fields with different meanings, and so on.

We might change our schema definition:

``` ruby
SchemaTest.define :user do
  id
  string :first_name
  string :last_name
  url :avatar_url
end
```

... and then we change our user serialiser logic, and write a test for the new API version, and everything passes. Great, right?

No. Not great. Not great because while yes, the tests pass, we've actually _changed_ the output of the previous API version endpoints accidentally, and there will be nothing in the commit that suggests it.

So instead, what we can do is _version_ our schema definitions:

``` ruby
SchemaTest.define :user, version: 1 do
  id
  string :name
  url :avatar_url
end

SchemaTest.define :user, version: 2 do
  id
  string :first_name
  string :last_name
  url :avatar_url
end
```

And then use the correct version in each of our tests:

``` ruby
# v1 comment test
get :comment

assert_schema_validates response.body, schema_for(:comment, version: 1)

# v2 comment test
get :comment

assert_schema_validates response.body, schema_for(:comment, version: 2)
```

This way we can now be confident that our version 1 tests are actually verifying the genuine version 1 schema, and likewise for the version 2 tests.

But there's another hole that we're about to step in...

### Nested schemas

To be written


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'schema-test'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install schema-test

## Usage

Once the gem is in your bundle, add it to your tests:

### Minitest with Rails

At or near the top of `test_helper.rb` add the following:

``` ruby
require 'schema_test/minitest'
SchemaTest.configure do |config|
  config.domain = 'mydomain.com'
  config.definition_paths << Rails.root.join('test', 'schema_definitions')
end
SchemaTest.load!
```

Within `class ActiveSupport::TestCase` in the same file, add 

``` ruby
include SchemaTest::Minitest
```

Create the directory `test/schema_definitions`; within this directory (and any subdirectories) you can start to define your schemas. A simple one would be:

``` ruby
SchemaTest.define :user, version: 1 do
  id
  string :name
  url :avatar_url
  integer :follower_count
end
```

You can then make assertions using this schema in your tests. For example, if you have a controller action that responds with JSON version of a user, you might write a test like this:

``` ruby
test 'JSON returned matches schema' do
  user = User.first
  get :show, params: { id: user.id }

  json = JSON.parse(response.body)
  assert_valid_json_for_schema(json, :user, version: 1)
end
```

When you run this test, this gem will convert the schema definition you've given into JSON Schema, and then dynamically rewrite your test to verify against the fully-expanded schema. After you run the test, if you reload the file, you should see something like this:

``` ruby
test 'JSON returned matches schema' do
  user = User.first
  get :show, params: { id: user.id }

  json = JSON.parse(response.body)
  assert_valid_json_for_schema( # EXPANDED
    json, 
    {:version=>1,
      :schema=>
      {"$schema"=>"http://json-schema.org/draft-07/schema#",
        "$id"=>"http://mydomain/v1/user.json",
        "title"=>"user",
        "type"=>"object",
        "properties"=>
        {"id"=>{"type"=>"integer"},
          "name"=>{"type"=>"string"},
          "avatar_url"=>{"type"=>"string", "format"=>"uri"},
          "follower_count"=>{"type"=>"integer}},
        "required"=>["id", "name", "avatar_url", "follower_count"],
        "additionalProperties"=>false}}
  ) # END EXPANDED
end
```
Keeping the full schema directly in the tests means that it is **impossible** for us to accidentally impact any API endpoints with a distant schema change without also producing some change in the test files for those endpoints. That is the main benefit that this library tries to acheive.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lazyatom/schema-test. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SchemaTest project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/lazyatom/schema-test/blob/master/CODE_OF_CONDUCT.md).
