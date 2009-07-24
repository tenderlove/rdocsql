class CreateSourceFiles < ActiveRecord::Migration
  def self.up
    create_table :source_files do |t|
      t.string    :name
      t.boolean   :simple
      t.text      :description
      t.text      :requires
      t.datetime  :last_modified

      t.timestamps
    end

    create_table :code_objects_source_files, :id => false do |t|
      t.references :code_object, :source_file
    end
  end

  def self.down
    drop_table :source_files
  end
end
