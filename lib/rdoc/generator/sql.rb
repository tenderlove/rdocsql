require 'rdoc/generator'
require 'rdoc/rdoc'

class RDoc::Generator::SQL
  RDoc::RDoc.add_generator self

  class << self; alias :for :new end

  attr_accessor :class_dir, :file_dir

  MUTEX = Mutex.new

  def initialize options
    @options    = options
    @class_dir  = nil
    @file_dir   = nil
    @odir       = Pathname.new(options.op_dir).expand_path(Pathname.pwd)
    @fh         = nil
  end

  def generate top_levels
    @files    = top_levels
    @classes  = RDoc::TopLevel.all_classes_and_modules
    @methods  = @classes.map { |x| x.method_list }.flatten

    open(File.join(@odir, "rdoc.sql"), 'a') { |f|
      @fh = f
      create_tables
      write_files
      write_classes
    }
  end

  private
  def create_tables
    @fh.puts <<-eosql
      CREATE TABLE IF NOT EXISTS "source_files"
        ( "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          "name" varchar(255),
          "description" text,
          "requires" text,
          "last_modified" datetime,
          "created_at" datetime,
          "updated_at" datetime
        );
    eosql

    @fh.puts <<-eosql
      CREATE TABLE IF NOT EXISTS "class_objects"
        ( "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          "class_type" varchar(255),
          "full_name" varchar(255),
          "superclass_name" varchar(255),
          "description" text,
          "superclass_id" INTEGER,
          "created_at" datetime,
          "updated_at" datetime
        );
    eosql
  end

  def write_files
    @files.each do |file|
      requires = file.requires.map { |x| x.name }
      audit = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      values = [
        file.absolute_name,
        file.description,
        YAML.dump(requires),
        file.file_stat.mtime.utc.strftime('%Y-%m-%d %H:%M:%S'),
        audit,
        audit
      ].map { |x| e x }.join(", ")

      sql = <<-eosql
      INSERT INTO source_files
      (name, description, requires, last_modified, created_at, updated_at)
      VALUES
      (#{values});
      eosql
      @fh.puts sql
    end
  end

  def write_classes
    @classes.each do |klass|
      audit = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      values = [
        klass.type,
        klass.full_name,
        klass.type == 'class' ?
          (klass.superclass.full_name rescue klass.superclass) :
           nil,
        klass.description,
        nil,
        audit,
        audit
      ].map { |x| e x }.join(', ')

      sql = <<-eosql
      INSERT INTO class_objects
      (class_type, full_name, superclass_name, description,
       superclass_id, created_at, updated_at) VALUES
      (#{values});
      eosql
      @fh.puts sql
    end
  end

  def e string
    return 'NULL' unless string
    "'#{string.gsub(/'/, '\'\'')}'"
  end
end
