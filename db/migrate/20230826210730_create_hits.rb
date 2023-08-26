class CreateHits < ActiveRecord::Migration[6.1]
  def change
    create_table :hits do |t|
      t.references :user, null: false, foreign_key: true
      t.text :endpoint

      t.timestamps
    end
  end
end
