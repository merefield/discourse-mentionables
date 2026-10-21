# frozen_string_literal: true
class UpdateMentionablesPluginName < ActiveRecord::Migration[6.1]
  def up
    PluginStoreRow
      .where("plugin_name = 'mentionable_items'")
      .each do |record|
        if PluginStoreRow.where(plugin_name: "mentionables", key: record.key).exists?
          #
        else
          record.update(plugin_name: "mentionables")
        end
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
