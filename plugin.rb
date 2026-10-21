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

after_initialize do
  require_relative "lib/mentionables/engine"
  require_relative "lib/mentionables/source"
  require_relative "lib/mentionables/sources/topic_table"
  require_relative "lib/mentionables/import_result"
  require_relative "lib/mentionables/log"
  require_relative "lib/mentionables/post_process"
  require_relative "app/controllers/mentionables/admin_controller"
  require_relative "app/serializers/mentionables/log_serializer"
  require_relative "app/models/mentionable_item"
  require_relative "config/routes"
  require_relative "jobs/import_mentionable_items"
  require_relative "jobs/destroy_mentionable_items"

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
