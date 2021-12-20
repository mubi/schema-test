require 'spec_helper'

RSpec.describe SchemaTest::Definition do
  describe 'define' do
    it 'captures definitions of schemas using various types' do
      definition = SchemaTest.define :thing do
        integer :count
        string :name
        float :angle
        boolean :flag, desc: 'with a description'
        array :subthings, of: :integer
        datetime :published_at
        date :available_on
        url :source_uri
        html :description
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [
          SchemaTest::Property::Integer.new(:count),
          SchemaTest::Property::String.new(:name),
          SchemaTest::Property::Float.new(:angle),
          SchemaTest::Property::Boolean.new(:flag, 'with a description'),
          SchemaTest::Property::Array.new(:subthings, :integer),
          SchemaTest::Property::DateTime.new(:published_at),
          SchemaTest::Property::Date.new(:available_on),
          SchemaTest::Property::String.new(:source_uri),
          SchemaTest::Property::String.new(:description),
        ]
      )
      expect(definition).to match_schema(expected_schema)
    end

    it 'allows descriptions to be provided' do
      definition = SchemaTest.define :thing do
        string :name, desc: 'The name of the thing'
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [SchemaTest::Property::String.new(:name, 'The name of the thing')]
      )
      expect(definition).to match_schema(expected_schema)
    end

    it 'allows properties to marked as optional' do
      definition = SchemaTest.define :thing do
        optional string :title
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [SchemaTest::Property::String.new(:title).tap(&:optional!)]
      )
      expect(definition).to match_schema(expected_schema)
    end

    it 'allows properties of sub-objects to marked as optional' do
      definition = SchemaTest.define :thing do
        object :subthing do
          optional string :title
        end
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [
          SchemaTest::Property::Object.new(
            :subthing,
            properties: [SchemaTest::Property::String.new(:title).tap(&:optional!)]
          )
        ]
      )
      expect(definition).to match_schema(expected_schema)
    end

    it 'allows properties to be marked as nullable' do
      definition = SchemaTest.define :thing do
        nullable string :title
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [SchemaTest::Property::String.new(:title).tap(&:nullable!)]
      )
      expect(definition).to match_schema(expected_schema)
    end

    it 'allows properties of sub-objects to be marked as nullable' do
      definition = SchemaTest.define :thing do
        object :subthing do
          nullable string :title
        end
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [
          SchemaTest::Property::Object.new(
            :subthing,
            properties: [SchemaTest::Property::String.new(:title).tap(&:nullable!)]
          )
        ]
      )
      expect(definition).to match_schema(expected_schema)
    end

    describe 'common attribute shorthands' do
      it 'provides an id shortcut' do
        definition = SchemaTest.define :thing do
          id
        end

        expected_schema = SchemaTest::Definition.new(
          :thing,
          properties: [SchemaTest::Property::Integer.new(:id)]
        )
        expect(definition).to match_schema(expected_schema)
      end

      it 'provides a slug shortcut' do
        definition = SchemaTest.define :thing do
          slug
        end

        expected_schema = SchemaTest::Definition.new(
          :thing,
          properties: [SchemaTest::Property::String.new(:slug)]
        )
        expect(definition).to match_schema(expected_schema)
      end

      it 'provides an updated_at shortcut' do
        definition = SchemaTest.define :thing do
          updated_at
        end

        expected_schema = SchemaTest::Definition.new(
          :thing,
          properties: [SchemaTest::Property::DateTime.new(:updated_at)]
        )
        expect(definition).to match_schema(expected_schema)
      end

      it 'provides a created_at shortcut' do
        definition = SchemaTest.define :thing do
          created_at
        end

        expected_schema = SchemaTest::Definition.new(
          :thing,
          properties: [SchemaTest::Property::DateTime.new(:created_at)]
        )
        expect(definition).to match_schema(expected_schema)
      end
    end

    it 'allows versions to be set' do
      definition = SchemaTest.define :thing, version: 2 do
        string :name
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        version: 2,
        properties: [SchemaTest::Property::String.new(:name)]
      )
      expect(definition).to match_schema(expected_schema)

      wrong_version_schema = SchemaTest::Definition.new(
        :thing,
        version: 3,
        properties: [SchemaTest::Property::String.new(:name)]
      )
      expect(definition).not_to match_schema(wrong_version_schema)
    end

    it 'allows multiple versions of a schema to exist without interfering with each other' do
      v1_definition = SchemaTest.define :thing, version: 1 do
        string :name
      end

      v2_definition = SchemaTest.define :thing, version: 2 do
        string :title
      end

      expect(v1_definition).to match_schema(SchemaTest::Definition.new(:thing, version: 1, properties: [SchemaTest::Property::String.new(:name)]))
      expect(v2_definition).to match_schema(SchemaTest::Definition.new(:thing, version: 2, properties: [SchemaTest::Property::String.new(:title)]))
    end

    it 'allows arrays of objects to be defined without providing schemas for them' do
      thing = SchemaTest.define :thing do
        array :subthings do
          string :name
          integer :size
        end
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [
          SchemaTest::Property::Array.new(
            :subthings,
            SchemaTest::Property::AnonymousObject.new(
              properties: [
                SchemaTest::Property::String.new(:name),
                SchemaTest::Property::Integer.new(:size)
              ]
            )
          )
        ]
      )

      expect(thing).to match_schema(expected_schema)
    end

    it 'can allow collections of objects to be defined' do
      SchemaTest.define :thing do
        string :name
      end

      things = SchemaTest.collection :things, of: :thing

      expected_schema = SchemaTest::Collection.new(
        :things,
        :thing
      )
      expect(things).to match_schema(expected_schema)
    end

    it 'allows collections to be defined at the same time' do
      SchemaTest.define :thing, collection: :things, version: 3 do
        string :name
      end

      expected_schema = SchemaTest::Collection.new(
        :things,
        :thing,
        version: 3
      )

      expect(SchemaTest::Definition.find(:things, 3)).to match_schema(expected_schema)
    end

    it 'can handle schemas defined out of order' do
      car = SchemaTest.define :car do
        string :colour
        integer :price
        object :engine
      end
      SchemaTest.define :engine do
        integer :valves
        string :name
      end

      expected_schema = SchemaTest::Definition.new(
        :car,
        properties: [
          SchemaTest::Property::String.new(:colour),
          SchemaTest::Property::Integer.new(:price),
          SchemaTest::Property::Object.new(
            :engine,
            properties: [
              SchemaTest::Property::Integer.new(:valves),
              SchemaTest::Property::String.new(:name)
            ]
          )
        ]
      )
      expect(car).to match_schema(expected_schema)
    end

    it 'allows aliasing of inner objects to give them a different name' do
      SchemaTest.define :engine do
        integer :valves
        string :name
      end
      thing = SchemaTest.define :thing do
        object :engine, as: :motor
      end

      expected_schema = SchemaTest::Definition.new(
        :thing,
        properties: [
          SchemaTest::Property::Object.new(
            :motor,
            properties: [
              SchemaTest::Property::Integer.new(:valves),
              SchemaTest::Property::String.new(:name)
            ]
          )
        ]
      )
      expect(thing).to match_schema(expected_schema)
    end

    describe 'schema versioning' do
      it 'allows will default object versions to match definition version' do
        SchemaTest.define :engine, version: 1 do
          integer :valves
          string :name
        end
        SchemaTest.define :engine, version: 2 do
          integer :valves
          string :name
          string :fuel
        end
        car = SchemaTest.define :car, version: 2 do
          string :colour
          integer :price
          object :engine
        end

        expected_schema = SchemaTest::Definition.new(
          :car,
          version: 2,
          properties: [
            SchemaTest::Property::String.new(:colour),
            SchemaTest::Property::Integer.new(:price),
            SchemaTest::Property::Object.new(
              :engine,
              version: 2,
              properties: [
                SchemaTest::Property::Integer.new(:valves),
                SchemaTest::Property::String.new(:name),
                SchemaTest::Property::String.new(:fuel)
              ]
            )
          ]
        )
        expect(car).to match_schema(expected_schema)
      end

      it 'allows objects to reference specific schema versions of other objects' do
        SchemaTest.define :engine, version: 1 do
          integer :valves
          string :name
        end
        SchemaTest.define :engine, version: 2 do
          integer :valves
          string :name
          string :fuel
        end
        car = SchemaTest.define :car, version: 2 do
          string :colour
          integer :price
          object :engine, version: 1
        end

        expected_schema = SchemaTest::Definition.new(
          :car,
          version: 2,
          properties: [
            SchemaTest::Property::String.new(:colour),
            SchemaTest::Property::Integer.new(:price),
            SchemaTest::Property::Object.new(
              :engine,
              version: 1,
              properties: [
                SchemaTest::Property::Integer.new(:valves),
                SchemaTest::Property::String.new(:name)
              ]
            )
          ]
        )
        expect(car).to match_schema(expected_schema)
      end

      describe 'implicit versioning' do
        it 'will implicitly use objects of the same version if none is given' do
          SchemaTest.define :thing, version: 1 do
            string :version_1_name
          end

          SchemaTest.define :thing, version: 2 do
            string :version_2_name
          end

          v1_container = SchemaTest.define :container, version: 1 do
            object :thing
          end

          v2_container = SchemaTest.define :container, version: 2 do
            object :thing
          end

          expected_v1_schema = SchemaTest::Definition.new(
            :container,
            version: 1,
            properties: [
              SchemaTest::Property::Object.new(
                :thing,
                version: 1,
                properties: [
                  SchemaTest::Property::String.new(:version_1_name)
                ]
              )
            ]
          )

          expected_v2_schema = SchemaTest::Definition.new(
            :container,
            version: 2,
            properties: [
              SchemaTest::Property::Object.new(
                :thing,
                version: 2,
                properties: [
                  SchemaTest::Property::String.new(:version_2_name)
                ]
              )
            ]
          )

          expect(v1_container).to match_schema(expected_v1_schema)
          expect(v2_container).to match_schema(expected_v2_schema)
        end

        it 'will fall back to unversioned objects if no matching version exists' do
          SchemaTest.define :thing  do
            string :version_1_name
          end

          v1_container = SchemaTest.define :container, version: 1 do
            object :thing
          end

          v2_container = SchemaTest.define :container, version: 2 do
            object :thing
          end

          expected_v1_schema = SchemaTest::Definition.new(
            :container,
            version: 1,
            properties: [
              SchemaTest::Property::Object.new(
                :thing,
                version: nil,
                properties: [
                  SchemaTest::Property::String.new(:version_1_name)
                ]
              )
            ]
          )

          expected_v2_schema = SchemaTest::Definition.new(
            :container,
            version: 2,
            properties: [
              SchemaTest::Property::Object.new(
                :thing,
                version: nil,
                properties: [
                  SchemaTest::Property::String.new(:version_1_name)
                ]
              )
            ]
          )

          expect(v1_container).to match_schema(expected_v1_schema)
          expect(v2_container).to match_schema(expected_v2_schema)
        end
      end

      describe 'basing definitions on other definitions' do
        it 'allows objects to be based on previous versions' do
          SchemaTest.define :engine, version: 1 do
            integer :valves
            string :name
          end
          SchemaTest.define :engine, version: 2 do
            based_on :engine, version: 1

            string :fuel
          end
          car = SchemaTest.define :car, version: 2 do
            string :colour
            integer :price
            object :engine, version: 1
          end

          expected_schema = SchemaTest::Definition.new(
            :car,
            version: 2,
            properties: [
              SchemaTest::Property::String.new(:colour),
              SchemaTest::Property::Integer.new(:price),
              SchemaTest::Property::Object.new(
                :engine,
                version: 1,
                properties: [
                  SchemaTest::Property::Integer.new(:valves),
                  SchemaTest::Property::String.new(:name)
                ]
              )
            ]
          )
          expect(car).to match_schema(expected_schema)
        end

        it 'allows those definitions to be created out of order' do
          thing_2 = SchemaTest.define :thing, version: 2 do
            based_on :thing, version: 1

            string :name
          end

          SchemaTest.define :thing, version: 1 do
            id
          end

          expected_schema = SchemaTest::Definition.new(
            :thing,
            version: 2,
            properties: [
              SchemaTest::Property::String.new(:name),
              SchemaTest::Property::Integer.new(:id),
            ]
          )
          expect(thing_2).to match_schema(expected_schema)
        end

        it 'allows new fields to be added' do
          SchemaTest.define :thing, version: 1 do
            string :name
          end

          v2_thing = SchemaTest.define :thing, version: 2 do
            based_on :thing, version: 1
            integer :age
          end

          expected_schema = SchemaTest::Definition.new(
            :thing,
            version: 2,
            properties: [
              SchemaTest::Property::String.new(:name),
              SchemaTest::Property::Integer.new(:age)
            ]
          )

          expect(v2_thing).to match_schema(expected_schema)
        end

        it 'allows fields to be removed' do
          SchemaTest.define :thing, version: 1 do
            string :name
          end

          v2_thing = SchemaTest.define :thing, version: 2 do
            based_on :thing, version: 1, except: [:name]
            integer :age
          end

          expected_schema = SchemaTest::Definition.new(
            :thing,
            version: 2,
            properties: [
              SchemaTest::Property::Integer.new(:age)
            ]
          )

          expect(v2_thing).to match_schema(expected_schema)
        end

        it 'allows nested object fields to be redefined' do
          SchemaTest.define :thing, version: 1 do
            object :subthing do
              string :name
            end
          end

          v2_thing = SchemaTest.define :thing, version: 2 do
            based_on :thing, version: 1
            object :subthing do
              string :full_name
            end
          end

          expected_schema = SchemaTest::Definition.new(
            :thing,
            version: 2,
            properties: [
              SchemaTest::Property::Object.new(
                :subthing,
                version: 2,
                properties: [
                  SchemaTest::Property::String.new(:full_name)
                ]
              )
            ]
          )

          expect(v2_thing).to match_schema(expected_schema)
        end
      end
    end
  end

  it 'captures the file and line of its definition' do
    definition = SchemaTest.define :thing do
    end

    expect(definition.location).to match /#{__FILE__}:\d+/
  end
end
