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

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED
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

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED
  some_other_json_argument,
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

    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, :expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
  assert_schema( # EXPANDED
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
                                     [2, :assert_schema, :arg1, :arg2, :expanded_contents],
                                     [5, :assert_schema, :arg3, :arg4, :expanded_contents2]
                                   ])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
line 4
assert_schema( # EXPANDED
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
                                     [2, :assert_schema, :arg1, :arg2, :expanded_contents],
                                     [5, :assert_other_schema, :arg3, :arg4, :expanded_contents2]
                                   ])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED
  json,
  :arg1, {:version=>:arg2, :schema=>:expanded_contents}
) # END EXPANDED
line 3
line 4
assert_other_schema( # EXPANDED
  other_json,
  :arg3, {:version=>:arg4, :schema=>:expanded_contents2}
) # END EXPANDED
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
    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED
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
assert_schema( # EXPANDED
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
    rewriter = described_class.new(input, [[2, :assert_schema, :arg1, :arg2, expanded_contents]])
    expect(rewriter.output).to eq(<<~FILE)
line 1
line 2
assert_schema( # EXPANDED
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
end
