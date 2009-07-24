class SourceFile < ActiveRecord::Base
  has_and_belongs_to_many :code_objects
  serialize :requires
end
