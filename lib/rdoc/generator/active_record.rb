require 'rdoc/generator'
require 'rdoc/rdoc'

class RDoc::Generator::ActiveRecord
  RDoc::RDoc.add_generator self

  class << self
    alias :for :new
  end

  def bar
  end

  alias :foo :bar

  attr_accessor :class_dir, :file_dir

  RAILS_ROOT = ENV['RAILS_ROOT']

  def initialize options
    @options    = options
    @class_dir  = nil
    @file_dir   = nil
    @odir       = Pathname.new(options.op_dir).expand_path(Pathname.pwd)
    @fh         = nil
    require File.join(RAILS_ROOT, 'config', 'environment')
  end

  ##
  # Generate some stuff
  def generate top_levels
    @files    = top_levels
    @classes  = RDoc::TopLevel.all_classes_and_modules
    @methods  = @classes.map { |x| x.method_list }.flatten

    @class_cache = {}
    @file_cache = {}

    write_files
    write_classes
    write_methods
  end

  private
  def write_methods
    @methods.each do |method|
      MethodObject.create!(
        :name         => method.name,
        :method_type  => method.type,
        :visibility   => method.visibility.to_s,
        :aliases      => method.aliases.map { |x| x.name },
        :alias_for    => (method.is_alias_for.name rescue nil),
        :aref         => method.aref,
        :call_seq     => method.call_seq,
        :params       => method.params,
        :description  => method.description,
        :markup_code  => method.markup_code,
        :parent       => @class_cache[method.parent.full_name]
      )
    end
  end

  def write_files
    @files.each do |file|
      @file_cache[file.absolute_name] = SourceFile.create!(
        :name           => file.absolute_name,
        :simple         => file.parser == RDoc::Parser::Simple,
        :description    => file.description.strip,
        :requires       => file.requires.map { |x| x.name },
        :last_modified  => file.file_stat.mtime
      )
    end
  end

  def write_classes
    @classes.each do |klass|
      ar_class = ClassObject.create!(
        :name             => klass.full_name,
        :class_type       => klass.type,
        :superclass_name  => klass.type == 'class' ?
          (klass.superclass.full_name rescue klass.superclass) :
           nil,
        :description      => klass.description.strip
      )
      @class_cache[klass.full_name] = ar_class

      klass.in_files.each do |file|
        @file_cache[file.absolute_name].code_objects << ar_class
      end

      klass.each_attribute do |attrib|
        AttributeObject.create!(
          :name         => attrib.name,
          :access       => attrib.rw,
          :description  => attrib.description.strip,
          :parent       => ar_class
        )
      end

      klass.each_constant do |const|
        ConstantObject.create!(
          :name         => const.name,
          :parent       => ar_class,
          :description  => const.description.strip
        )
      end
    end

    @classes.each do |klass|
      (klass.modules + klass.classes).each do |mod|
        record = @class_cache[mod.full_name]
        record.parent = @class_cache[klass.full_name]
        record.save!
      end
    end
  end
end
