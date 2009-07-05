require 'rubygems'
require "test/unit"
require "rdoc/generator/sql"
require 'amalgalite'
require 'tempfile'

class RDoc::Generator::SQL
  class << self
    attr_accessor :fake_file
  end

  def open *args
    self.class.fake_file = FakeFile.new(*args)
    yield self.class.fake_file
  end

  class FakeFile
    attr_accessor :filename, :mode, :db

    def initialize filename, mode
      @filename = filename
      @mode     = mode
      @db_name  = File.join(Dir.tmpdir, "#{Time.now.to_f}.db")
      @db = Amalgalite::Database.new(@db_name)
    end

    def puts sql
      @db.execute sql
    end
  end
end

class A
end

class B < A
  attr_accessor :foo
end

##
# Hello world!
class TestRdocsql < Test::Unit::TestCase
  def setup
    rdoc    = RDoc::RDoc.new
    rdoc.document ['-q', '-f', 'sql']
    @db = RDoc::Generator::SQL.fake_file.db
  end

  def teardown
    RDoc::Generator::SQL.fake_file = nil
    FileUtils.rm_rf('doc')
  end

  def test_source_files
    assert 0 < @db.execute('select * from source_files').length
  end

  def test_classes
    assert 0 < @db.execute('select * from code_objects where type = "ClassObject"').length
    superclass = @db.execute('select superclass_id from code_objects')
    assert superclass.flatten.compact.length > 0
  end

  def test_method_objects
    assert 0 < @db.execute('select * from code_objects where type = "MethodObject"').length
    @db.execute('select parent_id from code_objects where type = "MethodObject"') do |row|
      assert_not_nil row.first
    end
  end

  def test_attrbutes
    row = @db.execute('select id from code_objects where name = ?', 'B')
    id = row.flatten.first
    aliases = @db.execute(
      'select id from code_objects where parent_id = ? and type = ?',
       id,
       'AttributeObject'
    )
    assert_equal 1, aliases.length
  end
end
