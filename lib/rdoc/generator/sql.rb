require 'rdoc/generator'
require 'rdoc/rdoc'

class RDoc::Generator::SQL
  RDoc::RDoc.add_generator self

  class << self
    alias :for :new
  end

  def bar
  end

  alias :foo :bar

  attr_accessor :class_dir, :file_dir

  MUTEX = Mutex.new

  def initialize options
    @options    = options
    @class_dir  = nil
    @file_dir   = nil
    @odir       = Pathname.new(options.op_dir).expand_path(Pathname.pwd)
    @fh         = nil
  end

  ##
  # Generate some stuff
  def generate top_levels
    @files    = top_levels
    @classes  = RDoc::TopLevel.all_classes_and_modules
    @methods  = @classes.map { |x| x.method_list }.flatten

    open(File.join(@odir, "rdoc.sql"), 'a') { |f|
      @fh = f
      create_tables
      write_files
      write_classes
      write_methods
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
          "name" varchar(255),
          "superclass_name" varchar(255),
          "description" text,
          "superclass_id" INTEGER,
          "created_at" datetime,
          "updated_at" datetime
        );
    eosql

    @fh.puts <<-eosql
      CREATE TABLE IF NOT EXISTS "method_objects"
        ( "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          "name" varchar(255),
          "parent_name" varchar(255),
          "visibility" varchar(255),
          "alias_for" varchar(255),
          "call_seq" text,
          "params" text,
          "description" text,
          "markup_code" text,
          "class_object_id" INTEGER,
          "created_at" datetime,
          "updated_at" datetime
        );
    eosql
  end

  def write_methods

    @methods.each do |method|
      audit = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      values = ([
        method.name,
        method.parent.full_name,
        method.visibility.to_s,
        (method.is_alias_for.name rescue nil),
        method.call_seq,
        method.params,
        method.description,
        method.markup_code,
      ].map { |x| e x } + [
        "(select id from class_objects where name = #{e method.parent.full_name})",
        e(audit),
        e(audit)
      ]).join(', ')

      sql = <<-eosql
      INSERT INTO method_objects
      (
        name,
        parent_name,
        visibility,
        alias_for,
        call_seq,
        params,
        description,
        markup_code,
        class_object_id,
        created_at,
        updated_at
      ) VALUES (#{values})
      eosql
      @fh.puts sql
    end

    #needs aliass
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
      (class_type, name, superclass_name, description,
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
