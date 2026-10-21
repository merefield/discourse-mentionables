# frozen_string_literal: true
module ::Mentionables
  PLUGIN_NAME = "mentionables"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Mentionables
  end

  def self.info
    Hash[total: MentionableItem.all.size]
  end

  def self.items_for_client
    associations = []
    DiscourseEvent.trigger(:mentionables_preload_items, associations)
    MentionableItem
      .includes(associations)
      .map do |item|
        attributes = item.as_json(only: %i[id slug name url image_url])
        DiscourseEvent.trigger(:mentionables_serialize_item, item, attributes)
        attributes
      end
  end
end
