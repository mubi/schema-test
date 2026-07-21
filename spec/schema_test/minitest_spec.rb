require 'spec_helper'
require 'schema_test/minitest'
require 'tempfile'

RSpec.describe SchemaTest::Minitest do
  let(:harness) do
    Class.new do
      include SchemaTest::Minitest
    end.new
  end

  it 'serializes concurrent rewrites of the same file' do
    file = Tempfile.new
    file.write("original\n")
    file.close

    first_started = Queue.new
    release_first = Queue.new
    second_started = Queue.new
    second_contents = Queue.new

    first = Thread.new do
      harness.send(:rewrite_file_safely, file.path) do
        first_started << true
        release_first.pop
        "first\n"
      end
    end
    first_started.pop

    second = Thread.new do
      second_started << true
      harness.send(:rewrite_file_safely, file.path) do |contents|
        second_contents << contents
        "second\n"
      end
    end
    second_started.pop

    expect(second_contents).to be_empty
    release_first << true

    [first, second].each(&:value)
    expect(second_contents.pop).to eq("first\n")
    expect(File.read(file.path)).to eq("second\n")
  ensure
    file&.unlink
  end
end
