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
    assert 0 < @db.execute('select * from class_objects').length
  end

  def test_method_objects
    assert 0 < @db.execute('select * from method_objects').length
    @db.execute('select class_object_id from method_objects') do |row|
      assert_not_nil row.first
    end
  end
end
