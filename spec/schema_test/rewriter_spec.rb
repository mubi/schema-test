require 'spec_helper'
require 'schema_test/rewriter'

RSpec.describe SchemaTest::Rewriter do
  it 'replaces a definition line with full expansion' do
    input = <<~FILE
line 1
line 2
assert_schema(json, arg1, version: arg2)
line 3
     FILE

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
     FILE
  end

  it 'replaces a definition line calling the correct original json data argument' do
    input = <<~FILE
line 1
line 2
assert_schema(some_other_json_argument, arg1, version: arg2)
line 3
     FILE

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  some_other_json_argument,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
     FILE
  end

  it 'can handle obscure statements to get the JSON argument' do
    input = <<~FILE
line 1
line 2
assert_schema(object.method(something).json, arg1, version: arg2)
line 3
     FILE

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  object.method(something).json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
     FILE
  end

  it 'replaces definitions with the correct indent' do
    input = <<~FILE
line 1
line 2
  assert_schema(json, arg1, version: arg2)
line 3
    FILE

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
  assert_schema( # EXPANDED from path/schema.rb:1
    json,
    :arg1, {:version=>:arg2, :schema=>:expanded_contents}
  ) # END EXPANDED
line 3
     FILE
  end

  it 'replaces multiple definitions' do
    input = <<~FILE
line 1
line 2
assert_schema(json, arg1, arg2)
line 3
line 4
assert_schema(json, arg3, arg4)
line 5
    FILE

    rewriter = described_class.new(input, [
                                     [2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [5, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:12', :expanded_contents2]
                                   ])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
line 4
assert_schema( # EXPANDED from path/other_schema.rb:12
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
line 5
     FILE
  end

  it 'replaces multiple definitions with different calls' do
    input = <<~FILE
line 1
line 2
assert_schema(json, arg1, arg2)
line 3
line 4
assert_other_schema(other_json, arg3, arg4)
line 5
    FILE

    rewriter = described_class.new(input, [
                                     [2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [5, :assert_other_schema, :arg3, :arg4, 'path/schema.rb:1', :expanded_contents2]
                                   ])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
line 4
assert_other_schema(other_json, :arg3, version: :arg4) # schema from path/schema.rb:1
line 5
     FILE
  end

  it 'pretty-prints the expanded contents' do
    input = <<~FILE
line 1
line 2
assert_schema(json, arg1, version: arg2)
line 3
     FILE

    expanded_contents = {
      thing: 123,
      other_thing: {
        inner_thing: [1,2,3,4],
        value: 'stuff',
        boolean_value: true,
        float_value: 1.23
      }
    }
    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
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
line 3
     FILE
  end

  it 'modifies previously-expanded calls' do
    input = <<~FILE
line 1
line 2
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
line 3
     FILE

    expanded_contents = {
      thing: 456,
      other_thing: {
        inner_thing: [7,8,9],
        value: 'other stuff',
        boolean_value: false
      }
    }
    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1,
   {:version=>:arg2,
    :schema=>
     {:thing=>456,
      :other_thing=>
       {:inner_thing=>[7, 8, 9], :value=>"other stuff", :boolean_value=>false}}}
) # END EXPANDED
line 3
     FILE
  end

  it 'handles when previous definitions are expanded already' do
    input = <<~FILE
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 7
line 8
assert_schema(json, arg3, arg4)
line 10
    FILE

    rewriter = described_class.new(input, [
                                     [2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [8, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:12', :expanded_contents2]
                                   ])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 7
line 8
assert_schema( # EXPANDED from path/other_schema.rb:12
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
line 10
     FILE
  end

  it 'disables rubocop when expanding code if requested' do
    input = <<~FILE
line 1
line 2
assert_schema(json, arg1, arg2)
line 3
     FILE

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]], options: { disable_rubocop: true })
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 3
     FILE
  end

  it 'handles previously expanded code with rubocop disabled' do
    input = <<~FILE
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 9
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
     FILE

    rewriter = described_class.new(input, [
                                     [3, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [10, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:10', :expanded_contents2]
                                   ], options: { disable_rubocop: true })
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 9
# rubocop:disable all
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
# rubocop:enable all
     FILE
  end

  it 'removes rubocop blocks from previously expanded code if requested' do
    input = <<~FILE
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 3
     FILE

    rewriter = described_class.new(input, [[3, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
     FILE
  end

  it 'handles a mix of rubocop blocks and non-rubocop blocks' do
    input = <<~FILE
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 9
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents2}
) # END EXPANDED
    FILE

    rewriter = described_class.new(input, [
                                     [3, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [9, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:10', :expanded_contents2]
                                   ], options: { disable_rubocop: true })
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 9
# rubocop:disable all
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
# rubocop:enable all
    FILE
  end

  it 'handles mismatched rubocop blocks' do
    input = <<~FILE
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 8
# rubocop:disable all
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents2}
) # END EXPANDED
    FILE

    rewriter = described_class.new(input, [
                                     [2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [8, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:10', :expanded_contents2]
                                   ], options: { disable_rubocop: true })
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 8
# rubocop:disable all
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
# rubocop:enable all
    FILE
  end

  it 'can disable a mix of rubocop and non-rubocop blocks' do
    input = <<~FILE
line 1
line 2
# rubocop:disable all
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 9
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents2}
) # END EXPANDED
    FILE

    rewriter = described_class.new(input, [
                                     [3, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [9, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:10', :expanded_contents2]
                                   ])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 9
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
    FILE
  end

  it 'can disable mismatched rubocop blocks' do
    input = <<~FILE
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
# rubocop:enable all
line 8
# rubocop:disable all
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents2}
) # END EXPANDED
    FILE

    rewriter = described_class.new(input, [
                                     [2, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
                                     [8, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:10', :expanded_contents2]
                                   ])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 8
assert_schema( # EXPANDED from path/other_schema.rb:10
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
    FILE
  end

  context 'deduplication of repeated definition locations' do
    it 'does not expand the schema for the second use of the same definition location' do
      input = <<~FILE
line 1
assert_schema(json, arg1, version: arg2)
line 3
assert_schema(other_json, arg1, version: arg2)
line 5
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [3, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
assert_schema(other_json, :arg1, version: :arg2) # schema from path/schema.rb:1
line 5
      FILE
    end

    it 'does not expand the schema for third or subsequent uses' do
      input = <<~FILE
line 1
assert_schema(json1, arg1, version: arg2)
line 3
assert_schema(json2, arg1, version: arg2)
line 5
assert_schema(json3, arg1, version: arg2)
line 7
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [3, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [5, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json1,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
assert_schema(json2, :arg1, version: :arg2) # schema from path/schema.rb:1
line 5
assert_schema(json3, :arg1, version: :arg2) # schema from path/schema.rb:1
line 7
      FILE
    end

    it 'still expands each unique definition location' do
      input = <<~FILE
line 1
assert_schema(json, arg1, version: arg2)
line 3
assert_schema(json, arg3, version: arg4)
line 5
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [3, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:5', :expanded_contents2]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
assert_schema( # EXPANDED from path/other_schema.rb:5
  json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
line 5
      FILE
    end

    it 'expands each unique location once when mixed with duplicates' do
      input = <<~FILE
line 1
assert_schema(json1, arg1, version: arg2)
line 3
assert_schema(json2, arg3, version: arg4)
line 5
assert_schema(json3, arg1, version: arg2)
line 7
assert_schema(json4, arg3, version: arg4)
line 9
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [3, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:5', :expanded_contents2],
        [5, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [7, :assert_schema, :arg3, :arg4, 'path/other_schema.rb:5', :expanded_contents2]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json1,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
assert_schema( # EXPANDED from path/other_schema.rb:5
  json2,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
line 5
assert_schema(json3, :arg1, version: :arg2) # schema from path/schema.rb:1
line 7
assert_schema(json4, :arg3, version: :arg4) # schema from path/other_schema.rb:5
line 9
      FILE
    end

    it 'preserves indentation for non-expanded occurrences' do
      input = <<~FILE
line 1
  assert_schema(json, arg1, version: arg2)
line 3
  assert_schema(other_json, arg1, version: arg2)
line 5
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [3, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
  assert_schema( # EXPANDED from path/schema.rb:1
    json,
    :arg1, {:version=>:arg2, :schema=>:expanded_contents}
  ) # END EXPANDED
line 3
  assert_schema(other_json, :arg1, version: :arg2) # schema from path/schema.rb:1
line 5
      FILE
    end

    it 'rewrites a previously-expanded duplicate back to the short form' do
      input = <<~FILE
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 6
assert_schema( # EXPANDED from path/schema.rb:1
  other_json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 11
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [6, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 6
assert_schema(other_json, :arg1, version: :arg2) # schema from path/schema.rb:1
line 11
      FILE
    end

    it 'correctly outputs name and version arguments in the short form' do
      input = <<~FILE
line 1
assert_schema(json, arg1, version: arg2)
line 3
assert_schema(other_json, arg1, version: arg2)
line 5
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :users, 2, 'path/schema.rb:1', :expanded_contents],
        [3, :assert_schema, :users, 2, 'path/schema.rb:1', :expanded_contents]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :users, {:version=>2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
assert_schema(other_json, :users, version: 2) # schema from path/schema.rb:1
line 5
      FILE
    end

    it 'is idempotent when re-processing already-deduplicated output' do
      input = <<~FILE
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 6
assert_schema(other_json, :arg1, version: :arg2) # schema from path/schema.rb:1
line 8
      FILE

      rewriter = described_class.new(input, [
        [1, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents],
        [6, :assert_schema, :arg1, :arg2, 'path/schema.rb:1', :expanded_contents]
      ])
      expect(rewriter.output).to eq(<<~FILE)
line 1
assert_schema( # EXPANDED from path/schema.rb:1
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 6
assert_schema(other_json, :arg1, version: :arg2) # schema from path/schema.rb:1
line 8
      FILE
    end
  end

end
