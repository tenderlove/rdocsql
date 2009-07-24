class CreateCodeObjects < ActiveRecord::Migration
  def self.up
    create_table :code_objects do |t|
      t.integer :parent_id
      t.integer :superclass_id
      t.string  :type
      t.string  :name
      t.string  :access
      t.string  :aref
      t.string  :alias_for
      t.string  :class_type
      t.string  :method_type
      t.string  :visibility
      t.string  :superclass_name
      t.text    :aliases
      t.text    :call_seq
      t.text    :params
      t.text    :description
      t.text    :markup_code

      t.timestamps
    end
  end

  def self.down
    drop_table :code_objects
  end
end
