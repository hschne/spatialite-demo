class CreateStates < ActiveRecord::Migration[8.1]
  def change
    create_table :states do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.column :geometry, :blob

      t.timestamps
    end

    add_index :states, :code, unique: true
    add_index :states, :name, unique: true
  end
end
