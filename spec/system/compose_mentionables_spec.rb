# frozen_string_literal: true

require_relative "page_objects/mentionables"

RSpec.describe "Compose mentionables" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:composer) { PageObjects::Components::MentionableComposer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.mentionables_enabled = true
    SiteSetting.approve_post_count = 0
    MentionableItem.create!(
      name: "Example book",
      slug: "example-book",
      url: "https://example.com/book",
    )
    sign_in(user)
  end

  it "lets a user autocomplete a mention in Markdown, preview it, and publish its link" do
    user.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])
    topic_page.visit_topic_and_open_composer(topic)
    expect(composer).to have_no_table_button
    composer.fill_content("Read this excellent book ")
    composer.click_toolbar_button("insert-mentionable")
    expect(composer).to have_suggestion("Example book")
    composer.type_content("exa")
    expect(composer).to have_suggestion("Example book")
    composer.choose_mention("Example book")
    expect(composer).to have_preview_link("Example book", "https://example.com/book")
    composer.type_content(".")
    composer.create
    expect(composer).to have_post_link("Example book", "https://example.com/book")
    page.refresh
    expect(composer).to have_post_link("Example book", "https://example.com/book")
  end

  it "lets a user select a mention in the rich editor and publish its link" do
    user.user_option.update!(composition_mode: UserOption.composition_mode_types[:rich])
    topic_page.visit_topic_and_open_composer(topic)
    expect(composer).to have_rich_editor
    composer.type_content("Read this excellent book ")
    composer.click_toolbar_button("insert-mentionable")
    expect(composer).to have_suggestion("Example book")
    composer.type_content("exa")
    expect(composer).to have_suggestion("Example book")
    composer.choose_mention("Example book")
    expect(composer).to have_rich_editor
    composer.type_content(".")
    composer.create
    expect(composer).to have_post_link("Example book", "https://example.com/book")
  end

  it "keeps mentions inside code as code" do
    user.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])
    topic_page.visit_topic_and_open_composer(topic)
    composer.fill_content("Read this code sample: `+example-book`")
    expect(composer).to have_no_suggestions
    composer.create
    expect(composer).to have_post_code("+example-book")
  end

  it "hides the mention button when the plugin is disabled" do
    SiteSetting.mentionables_enabled = false
    topic_page.visit_topic_and_open_composer(topic)
    expect(composer).to have_no_mention_button
  end
end
