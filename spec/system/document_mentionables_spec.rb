# frozen_string_literal: true

require_relative "page_objects/mentionables"
require_relative "page_objects/mentionable_preview"
require_relative "page_objects/mentionables_documentation"

RSpec.describe "Document mentionables" do
  fab!(:admin) { Fabricate(:admin, username: "alex", name: "Alex Morgan") }
  fab!(:member) do
    Fabricate(:user, username: "sam", name: "Sam Taylor", trust_level: TrustLevel[2])
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:management) { PageObjects::Pages::Mentionables.new }
  let(:documentation) { PageObjects::Pages::MentionablesDocumentation.new }
  let(:composer) { PageObjects::Components::MentionableComposer.new }
  let(:preview) { PageObjects::Components::MentionablePreview.new }

  it "lets members discover and preview resources imported by an administrator" do
    SiteSetting.title = "Community Hub"
    SiteSetting.mentionables_enabled = true
    SiteSetting.mentionables_source = "topic_table" if defined?(MentionablesPro)
    SiteSetting.mentionables_pro_enabled = false if defined?(MentionablesPro)
    SiteSetting.approve_post_count = 0
    Jobs.run_immediately!

    source_topic = Fabricate(:topic, title: "Mentionables catalogue", user: admin)
    Fabricate(
      :post,
      user: admin,
      topic: source_topic,
      raw: File.read(File.expand_path("../fixtures/documentation/mentionables.md", __dir__)),
    )
    SiteSetting.mentionables_topic_id = source_topic.id

    sign_in(admin)
    documentation.prepare_viewport
    topic_page.visit_topic(source_topic)
    expect(documentation).to have_source_table
    documentation.capture("source-table")

    management.open
    management.import
    expect(management).to have_message("import_started")
    management.refresh
    expect(management).to have_total(3)
    management.expand_log(I18n.t("js.mentionables.log.report.title"))
    expect(management).to have_details(I18n.t("js.mentionables.log.report.success", count: 3))
    documentation.capture("import-report")

    stub_request(:head, "https://example.com/handbook").to_return(status: 200)
    stub_request(:get, "https://example.com/handbook").to_return(
      status: 200,
      headers: {
        "Content-Type" => "text/html",
      },
      body: File.read(File.expand_path("../fixtures/documentation/handbook.html", __dir__)),
    )
    discussion = Fabricate(:topic, title: "A few useful resources for new members", user: member)
    post = Fabricate(:post, user: member, topic: discussion, raw: <<~MARKDOWN)
          Welcome! Our +community-handbook is a useful place to start. Explore +getting-started and +events-calendar when you are ready.

          Here is our handbook, with everything you need to feel at home:

          +community-handbook
        MARKDOWN
    post.rebake!

    member.user_option.update!(composition_mode: UserOption.composition_mode_types[:markdown])
    sign_in(member)
    topic_page.visit_topic(discussion)
    expect(preview).to have_standalone_card("Community handbook")
    preview.hover_pill
    expect(preview).to have_card("Community handbook")
    documentation.capture("onebox-preview")
    preview.close

    topic_page.visit_topic_and_open_composer(discussion)
    composer.fill_content("Useful links for new members: ")
    composer.click_toolbar_button("insert-mentionable")
    expect(composer).to have_suggestion("Community handbook")
    expect(composer).to have_suggestion("Getting started")
    expect(composer).to have_suggestion("Events calendar")
    documentation.capture("composer-autocomplete")
    composer.choose_mention("Community handbook")
    expect(composer).to have_preview_link("Community handbook", "https://example.com/handbook")
  end
end
