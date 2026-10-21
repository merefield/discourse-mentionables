# frozen_string_literal: true

require_relative "page_objects/mentionables"

RSpec.describe "Insert mentionables tables" do
  fab!(:admin)
  fab!(:post)

  let(:composer) { PageObjects::Components::MentionableComposer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.mentionables_enabled = true
    SiteSetting.mentionables_pro_enabled = false if defined?(MentionablesPro)
    sign_in(admin)
  end

  it "lets an administrator insert a Markdown table skeleton" do
    admin.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])
    topic_page.visit_topic_and_open_composer(post.topic)

    composer.click_toolbar_button("insert-mentionables-table")

    expect(composer).to have_table_skeleton
  end

  it "lets an administrator insert an editable table in the rich composer" do
    admin.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    topic_page.visit_topic_and_open_composer(post.topic)
    expect(composer).to have_rich_editor

    composer.click_toolbar_button("insert-mentionables-table")

    expect(composer).to have_rich_table_skeleton
  end
end
