# frozen_string_literal: true

class CreateMentionableItems < ActiveRecord::Migration[5.2]
  def up
    create_table :mentionable_items do |t|
      t.string :url, null: false
      t.string :name, null: false
      t.string :name_slug
      t.string :image_url
      t.string :description
      t.string :affiliate_snippet_1
      t.string :affiliate_snippet_2
      t.string :affiliate_snippet_3
      t.datetime :created_at
      t.datetime :updated_at
    end

    add_index :mentionable_items, :url, unique: true
  end

  def down
    drop_table :mentionable_items
  end
end
