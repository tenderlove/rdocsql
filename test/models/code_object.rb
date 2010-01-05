class CodeObject < ActiveRecord::Base
  has_and_belongs_to_many :source_files

  def parent
    self.class.find read_attribute "parent_id"
  end

  def parent= object
    write_attribute "parent_id", object.id
  end

  def children
    CodeObject.find_all_by_parent_id(self.id)
  end
end
