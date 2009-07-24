class ClassObject < CodeObject
  has_many :method_objects, :foreign_key => 'parent_id'

  def methods
    method_objects
  end

  def constants
    children.find_all { |x| ConstantObject === x }.sort_by { |x| x.name }
  end

  def attributes
    children.find_all { |x| AttributeObject === x }.sort_by { |x| x.name }
  end

  def superclass
    ClassObject.find_by_name(superclass_name)
  end
end
