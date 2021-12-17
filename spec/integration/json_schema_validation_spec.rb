require 'spec_helper'

RSpec.describe 'validating JSON using JSON Schema' do
  describe 'a simple object' do
    let(:definition) do
      SchemaTest.define :thing do
        integer :widget_count
      end
    end

    it 'accepts json with fully matching keys' do
      expect(definition).to validate_json(widget_count: 123)
    end

    it 'rejects json with the wrong keys' do
      expect(definition).not_to validate_json(other_widget_count: 123)
    end

    it 'rejects json with empty non-optional value' do
      expect(definition).not_to validate_json(widget_count: nil)
    end

    it 'rejects json with extra keys' do
      expect(definition).not_to validate_json(widget_count: 123, other_widget_count: 456).because('object contains the extra key: /other_widget_count')
    end

    it 'rejects json with the wrong type of widget_count' do
      expect(definition).not_to validate_json(widget_count: 'not an integer').because(%{value at /widget_count ("not an integer") failed validation: type should be integer})
    end
  end

  describe 'a more complex object' do
    let(:definition) do
      SchemaTest.define :thing do
        string :name
        integer :size
        optional url :url
        optional array :sizes, of: :integer
      end
    end

    it 'validates with or without the optional properties' do
      expect(definition).to validate_json(name: 'wem', size: 1)
      expect(definition).to validate_json(name: 'wem', size: 1, url: 'http://example.com')
    end

    it 'validates the format of properties' do
      expect(definition).not_to validate_json(name: 'wem', size: 1, url: 'not-a-url').because(%{value at /url ("not-a-url") failed validation: format should be uri})
      expect(definition).not_to validate_json(name: 'wem', size: 'not-a-number').because(%{value at /size ("not-a-number") failed validation: type should be integer})
    end

    it 'validates internal types of arrays' do
      expect(definition).to validate_json(name: 'wem', size: 1, sizes: [1,2,3])
      expect(definition).not_to validate_json(name: 'wem', size: 1, sizes: [1,2,'c']).because(%{value at /sizes/2 ("c") failed validation: type should be integer})
    end
  end

  describe 'an object with nullable values' do
    let(:definition) do
      SchemaTest.define :thing do
        nullable integer :age
      end
    end

    it 'validates when property either matches type or is nil' do
      expect(definition).to validate_json(age: 100)
      expect(definition).to validate_json(age: nil)
    end

    it 'does not validate if the key is missing' do
      expect(definition).not_to validate_json(not_age: 100).because(%{object contains the extra key: /not_age})
    end

    it 'does not validate if the key is present and not the expected type' do
      expect(definition).not_to validate_json(age: 'not-a-number').because(%{value at /age ("not-a-number") failed validation: type should be one of ["integer", "null"]})
    end
  end

  describe 'a nested object' do
    let(:definition) do
      SchemaTest.define :film do
        string :title
        integer :year
        array :directors do
          string :name
          string :slug
        end
      end
    end

    it 'validates with a director' do
      film_with_director = {
        title: 'Pulp Fiction',
        year: 1998,
        directors: [
          { name: 'Quentin Tarantino', slug: 'quentin-tarantino' }
        ]
      }
      expect(definition).to validate_json(film_with_director)
    end

    it 'validates the internal director types' do
      film_with_director = {
        title: 'Pulp Fiction',
        year: 1998,
        directors: [
          { name: 'Quentin Tarantino', slug: 123 }
        ]
      }
      expect(definition).not_to validate_json(film_with_director).because(%{value at /directors/0/slug (123) failed validation: type should be string})
    end

    it 'validates required properties of the internal director structure' do
      film_with_director = {
        title: 'Pulp Fiction',
        year: 1998,
        directors: [
          { name: 'Quentin Tarantino' }
        ]
      }
      expect(definition).not_to validate_json(film_with_director).because(%{value at /directors/0 ({"name"=>"Quentin Tarantino"}) failed validation: missing some required attributes})
    end

    it 'validates multiple elements of an array' do
      film_with_two_directors = {
        title: 'The Matrix',
        year: 1999,
        directors: [
          {name: 'Lana Wachowski', slug: 'lana'},
          {name: 'Lara Wachowski' }
        ]
      }
      expect(definition).not_to validate_json(film_with_two_directors).because(%{value at /directors/1 ({"name"=>"Lara Wachowski"}) failed validation: missing some required attributes})

      film_with_two_directors[:directors].last[:slug] = 'lara'
      expect(definition).to validate_json(film_with_two_directors)
    end
  end

  describe 'a nested object of a referenced type' do
    let(:definition) do
      SchemaTest.define :director do
        string :name
        integer :age
      end

      SchemaTest.define :film do
        string :title
        integer :year
        object :director
      end
    end

    it 'validates with a director' do
      film_with_director = {
        title: 'Pulp Fiction',
        year: 1998,
        director: { name: 'Quentin Tarantino', age: 54 }
      }
      expect(definition).to validate_json(film_with_director)
    end
  end

  describe 'a nested array of referenced types' do
    let(:definition) do
      SchemaTest.define :director do
        string :name
        integer :age
      end

      SchemaTest.define :film do
        string :title
        integer :year
        array :directors, of: type(:director)
      end
    end

    it 'validates with a director' do
      film_with_director = {
        title: 'Pulp Fiction',
        year: 1998,
        directors: [
          { name: 'Quentin Tarantino', age: 54 }
        ]
      }
      expect(definition).to validate_json(film_with_director)
    end
  end

  describe 'a bare collection of objects' do
    let(:things) do
      SchemaTest.define :thing do
        string :name
      end

      SchemaTest.collection :things, of: :thing
    end

    it 'validates a bare collection' do
      expect(things).to validate_json([{name: 'Apple'}, {name: 'Banana'}])
    end

    it 'is not valid when empty' do
      expect(things).not_to validate_json([])
    end

    it 'is not valid if one of the elements does not validate the internal object' do
      expect(things).not_to validate_json([{name: 'Apple'}, {}])
    end
  end

  describe 'a collection of things with a root key' do
    let(:things) do
      SchemaTest.define :thing, version: 1 do
        string :name
      end

      SchemaTest.define :paginated_things, version: 1 do
        array :things, of: type(:thing)
        object :meta do
          integer :current_page
          integer :total_pages
          url :previous_page
          url :next_page
        end
      end
    end

    it 'validates a paginated collection with a root key' do
      expect(things).to validate_json({things: [{name: 'Apple'}], meta: {current_page: 1, total_pages: 1, previous_page: 'http://example.com/things/1', next_page: 'http://example.com/things/2'}})
    end
  end
end
