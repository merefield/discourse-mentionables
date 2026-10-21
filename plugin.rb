# frozen_string_literal: true
# name: discourse-mentionables
# about: Allows users to +mention custom data in posts
# version: 0.9.0
# required_version: 2026.10.0-latest
# authors: Robert Barrow, Angus McLeod
# url: https://github.com/merefield/discourse-mentionables

enabled_site_setting :mentionables_enabled
add_admin_route "mentionables.title", "mentionables", use_new_show_route: true
register_asset "stylesheets/common.scss"

register_svg_icon "cart-shopping"
register_svg_icon "table"

module ::Mentionables
  PLUGIN_NAME = "mentionables"

  def self.info
    { total: MentionableItem.count }
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

require_relative "lib/mentionables/engine"

after_initialize do
  add_to_serializer(:site, :mentionable_items) { Mentionables.items_for_client }

  on(:before_post_process_cooked) do |doc, post|
    Mentionables::PostProcess.add_links(doc, post) if SiteSetting.mentionables_enabled
  end

  DiscourseEvent.trigger(:mentionables_ready)
end

on(:custom_wizard_ready) do
  if defined?(CustomWizard) == "constant" && CustomWizard.class == Module
    CustomWizard::Field.register(
      "mentionables",
      "discourse-mentionables",
      %w[models lib stylesheets templates],
    )
    CustomWizard::WizardSerializer.attributes("mentionable_items")
    CustomWizard::WizardSerializer.public_send(:define_method, "include_mentionable_items?") do
      SiteSetting.mentionables_enabled
    end
    CustomWizard::WizardSerializer.public_send(:define_method, "mentionable_items") do
      Mentionables.items_for_client
    end
  end
end
