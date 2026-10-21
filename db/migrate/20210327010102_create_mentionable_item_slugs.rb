# frozen_string_literal: true
class CreateMentionableItemSlugs < ActiveRecord::Migration[5.2]
  def up
    create_table :mentionable_item_slugs do |t|
      t.string :name_slug
      t.string :name
      t.references :mentionable_item
    end
    add_index :mentionable_item_slugs, :name_slug, unique: true
    add_foreign_key :mentionable_item_slugs,
                    :mentionable_items,
                    column: :mentionable_item_id,
                    unique: true
  end
  def down
    drop_table :mentionable_item_slugs
  end
end
