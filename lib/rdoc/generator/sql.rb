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
      write_attributes
      write_constants
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
      CREATE TABLE IF NOT EXISTS "code_objects"
        ( "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          "parent_id"       INTEGER,
          "type"            varchar(255),
          "name"            varchar(255),
          "access"          varchar(255),
          "aliases"         text,
          "call_seq"        text,
          "params"          text,
          "alias_for"       varchar(255),
          "class_type"      varchar(255),
          "visibility"      varchar(255),
          "description"     text,
          "markup_code"     text,
          "superclass_id"   INTEGER,
          "superclass_name" varchar(255),
          "created_at"      datetime,
          "updated_at"      datetime
        );
    eosql
  end

  def write_methods
    @methods.each do |method|
      audit = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
      values = ([
        method.name,
        'MethodObject',
        method.visibility.to_s,
        YAML.dump(method.aliases.map { |x| x.name }),
        (method.is_alias_for.name rescue nil),
        method.call_seq,
        method.params,
        method.description,
        method.markup_code,
      ].map { |x| e x } + [
        "(select id from code_objects where name = #{e method.parent.full_name})",
        e(audit),
        e(audit)
      ]).join(', ')

      sql = <<-eosql
      INSERT INTO code_objects
      (
        name,
        type,
        visibility,
        aliases,
        alias_for,
        call_seq,
        params,
        description,
        markup_code,
        parent_id,
        created_at,
        updated_at
      ) VALUES (#{values})
      eosql
      @fh.puts sql
    end
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
      insert(
        :type             => 'ClassObject',
        :class_type       => klass.type,
        :name             => klass.full_name,
        :superclass_name  => klass.type == 'class' ?
          (klass.superclass.full_name rescue klass.superclass) :
           nil,
        :description      => klass.description.strip
      )
    end

    @fh.puts <<-eosql
    CREATE VIEW IF NOT EXISTS copy AS SELECT * FROM code_objects;
    eosql

    @fh.puts <<-eosql
    UPDATE code_objects SET superclass_id =
      (SELECT id FROM copy WHERE name = code_objects.superclass_name
        and type = "ClassObject");
    eosql

    @classes.each do |klass|
      (klass.modules + klass.classes).each do |mod|
        @fh.puts("UPDATE code_objects SET parent_id =
                 (SELECT id FROM copy WHERE name = #{e klass.full_name})
                 WHERE code_objects.name = #{e mod.full_name}
                 AND code_objects.type = 'ClassObject'
                 ")
      end
    end

    @fh.puts 'DROP VIEW copy'
  end

  def write_attributes
    @classes.each do |klass|
      klass.each_attribute do |attrib|
        insert({
          :name         => attrib.name,
          :access       => attrib.rw,
          :description  => attrib.description.strip,
          :type         => 'AttributeObject'
        }, {
          :parent_id    => "(select id from code_objects where name = #{e klass.name} and type = 'ClassObject')",
        })
      end
    end
  end

  def write_constants
    @classes.each do |klass|
      klass.each_constant do |const|
        insert({
          :name         => const.name,
          :type         => 'ConstantObject',
          :description  => const.description.strip
        }, {
          :parent_id    => "(select id from code_objects where name = #{e klass.name} and type = 'ClassObject')",
        })
      end
    end
  end

  def insert params = {}, escaped = {}
    audit = Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')
    columns = []
    values  = []

    params.each do |k,v|
      columns << k
      values << e(v)
    end

    escaped.each { |k,v| columns << k; values << v }

    columns += ['created_at', 'updated_at']
    values  += [e(audit), e(audit)]

    @fh.puts(<<-eosql)
      INSERT INTO code_objects
      (#{columns.join(', ')}) VALUES
      (#{values.join(', ')})
    eosql
  end

  def e string
    return 'NULL' unless string
    "'#{string.gsub(/'/, '\'\'')}'"
  end
end
