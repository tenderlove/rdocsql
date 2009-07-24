class MethodObject < CodeObject
  serialize :aliases

  named_scope :public, :conditions => { :visibility => 'public' }
  named_scope :class_type, :conditions => { :method_type => 'class' }
  named_scope :instance_type, :conditions => { :method_type => 'instance' }
end
