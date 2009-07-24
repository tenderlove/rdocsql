require 'rubygems'
require "test/unit"
require "rdoc/generator/active_record"
require 'tempfile'

$-w = false
require 'activerecord'
require 'migrations/create_source_files'
require 'migrations/create_code_objects'
$-w = true

RDoc::Generator::ActiveRecord.const_set(:RAILS_ROOT, File.dirname(__FILE__))
%w{
  code_object
  attribute_object
  class_object
  constant_object
  method_object
  source_file
}.each do |model|
  require "models/#{model}"
end

db_name = File.join(Dir.tmpdir, "#{Time.now.to_f}.db")

ActiveRecord::Base.establish_connection(
  :adapter  => 'sqlite3',
  :database => db_name
)

CreateCodeObjects.migrate :up
CreateSourceFiles.migrate :up

class A
end

class B < A
  FOO = 'bar'
  attr_accessor :foo
end

module Foo
  class Bar
  end
end

##
# Hello world!
class TestRdocsql < Test::Unit::TestCase
  def setup
    $-w = false
    rdoc    = RDoc::RDoc.new
    rdoc.document ['-q', '-f', 'activerecord']
    $-w = true
  end

  def teardown
    FileUtils.rm_rf(File.join(File.dirname(__FILE__), '..', 'doc'))
  end

  def test_class_object_count
    assert_equal 18, ClassObject.count
  end
end
