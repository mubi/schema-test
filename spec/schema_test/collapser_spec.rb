require 'spec_helper'
require 'schema_test/collapser'
require 'tmpdir'
require 'fileutils'

RSpec.describe SchemaTest::Collapser do
  it 'collapses a simple expanded assertion' do
    input = <<~FILE
      line 1
      line 2
      assert_schema( # EXPANDED from path/schema.rb:1
        json,
        :arg1, {:version=>:arg2, :schema=>:expanded_contents}
      ) # END EXPANDED
      line 3
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      line 1
      line 2
      assert_schema(json, :arg1, version: :arg2)
      line 3
    FILE
  end

  it 'preserves the json variable name' do
    input = <<~FILE
      assert_schema( # EXPANDED from path/schema.rb:1
        some_other_json_argument,
        :thing, {:version=>1, :schema=>:expanded_contents}
      ) # END EXPANDED
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      assert_schema(some_other_json_argument, :thing, version: 1)
    FILE
  end

  it 'preserves indentation' do
    input = <<~FILE
      line 1
          assert_schema( # EXPANDED from path/schema.rb:1
            json,
            :user, {:version=>2, :schema=>:expanded_contents}
          ) # END EXPANDED
      line 2
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      line 1
          assert_schema(json, :user, version: 2)
      line 2
    FILE
  end

  it 'collapses multiple expanded assertions in the same file' do
    input = <<~FILE
      assert_schema( # EXPANDED from path/schema.rb:1
        json,
        :user, {:version=>1, :schema=>:stuff}
      ) # END EXPANDED
      some other line
      assert_schema( # EXPANDED from path/other.rb:5
        other_json,
        :comment, {:version=>3, :schema=>:other_stuff}
      ) # END EXPANDED
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      assert_schema(json, :user, version: 1)
      some other line
      assert_schema(other_json, :comment, version: 3)
    FILE
  end

  it 'collapses assertions with multi-line pretty-printed schemas' do
    input = <<~FILE
      assert_schema( # EXPANDED from path/schema.rb:1
        json,
        :arg1,
         {:version=>:arg2,
          :schema=>
           {:thing=>123,
            :other_thing=>
             {:inner_thing=>[1, 2, 3, 4],
              :value=>"stuff",
              :boolean_value=>true,
              :float_value=>1.23}}}
      ) # END EXPANDED
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      assert_schema(json, :arg1, version: :arg2)
    FILE
  end

  it 'strips rubocop:disable/enable lines around expanded blocks' do
    input = <<~FILE
      line 1
      # rubocop:disable all
      assert_schema( # EXPANDED from path/schema.rb:1
        json,
        :user, {:version=>1, :schema=>:stuff}
      ) # END EXPANDED
      # rubocop:enable all
      line 2
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      line 1
      assert_schema(json, :user, version: 1)
      line 2
    FILE
  end

  it 'handles different method names' do
    input = <<~FILE
      assert_valid_json_for_schema( # EXPANDED from path/schema.rb:1
        response_json,
        :widget, {:version=>4, :schema=>:stuff}
      ) # END EXPANDED
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      assert_valid_json_for_schema(response_json, :widget, version: 4)
    FILE
  end

  it 'leaves non-expanded lines untouched' do
    input = <<~FILE
      line 1
      assert_schema(json, :user, version: 1)
      line 3
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      line 1
      assert_schema(json, :user, version: 1)
      line 3
    FILE
  end

  it 'handles a mix of expanded and non-expanded assertions' do
    input = <<~FILE
      assert_schema(json, :thing, version: 1)
      assert_schema( # EXPANDED from path/schema.rb:5
        other_json,
        :widget, {:version=>2, :schema=>:stuff}
      ) # END EXPANDED
      more code
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      assert_schema(json, :thing, version: 1)
      assert_schema(other_json, :widget, version: 2)
      more code
    FILE
  end

  it 'handles indented rubocop blocks' do
    input = <<~FILE
      line 1
        # rubocop:disable all
        assert_schema( # EXPANDED from path/schema.rb:1
          json,
          :user, {:version=>1, :schema=>:stuff}
        ) # END EXPANDED
        # rubocop:enable all
      line 2
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      line 1
        assert_schema(json, :user, version: 1)
      line 2
    FILE
  end

  it 'handles only rubocop:enable without rubocop:disable' do
    input = <<~FILE
      assert_schema( # EXPANDED from path/schema.rb:1
        json,
        :user, {:version=>1, :schema=>:stuff}
      ) # END EXPANDED
      # rubocop:enable all
      line 2
    FILE

    expect(described_class.new(input).output).to eq(<<~FILE)
      assert_schema(json, :user, version: 1)
      line 2
    FILE
  end
end

RSpec.describe 'SchemaTest.collapse!' do
  let(:tmpdir) { Dir.mktmpdir }

  after do
    FileUtils.remove_entry(tmpdir)
  end

  it 'collapses expanded assertions in the given files' do
    test_file = File.join(tmpdir, 'widget_test.rb')
    File.write(test_file, <<~FILE)
      test 'it works' do
        assert_schema( # EXPANDED from schema.rb:1
          json,
          :widget, {:version=>1, :schema=>:stuff}
        ) # END EXPANDED
      end
    FILE

    SchemaTest.collapse!(test_file)

    expect(File.read(test_file)).to eq(<<~FILE)
      test 'it works' do
        assert_schema(json, :widget, version: 1)
      end
    FILE
  end

  it 'skips files without expanded assertions' do
    test_file = File.join(tmpdir, 'clean_test.rb')
    original = <<~FILE
      test 'it works' do
        assert_schema(json, :widget, version: 1)
      end
    FILE
    File.write(test_file, original)

    SchemaTest.collapse!(test_file)

    expect(File.read(test_file)).to eq(original)
  end

  it 'globs for ruby files when given a directory' do
    subdir = File.join(tmpdir, 'controllers')
    FileUtils.mkdir_p(subdir)

    test_file = File.join(subdir, 'users_test.rb')
    File.write(test_file, <<~FILE)
      assert_schema( # EXPANDED from schema.rb:1
        json,
        :user, {:version=>1, :schema=>:stuff}
      ) # END EXPANDED
    FILE

    not_ruby = File.join(subdir, 'notes.txt')
    File.write(not_ruby, "just a text file with # EXPANDED in it\n")

    SchemaTest.collapse!(tmpdir)

    expect(File.read(test_file)).to eq(<<~FILE)
      assert_schema(json, :user, version: 1)
    FILE
    expect(File.read(not_ruby)).to eq("just a text file with # EXPANDED in it\n")
  end
end
