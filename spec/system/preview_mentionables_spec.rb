# frozen_string_literal: true

require_relative "page_objects/mentionable_preview"

RSpec.describe "Preview mentionables" do
  fab!(:user)
  fab!(:post) { Fabricate(:post, user: user, raw: "Read +example-book for more.\n\n+example-book") }

  let(:preview) { PageObjects::Components::MentionablePreview.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.mentionables_enabled = true
    SiteSetting.mentionables_pro_click_to_preview = false if defined?(MentionablesPro)
    MentionableItem.create!(
      name: "Example book",
      slug: "example-book",
      url: "https://example.com/book",
    )
    stub_request(:head, "https://example.com/book").to_return(status: 200)
    stub_request(:get, "https://example.com/book").to_return(
      status: 200,
      headers: {
        "Content-Type" => "text/html",
      },
      body:
        '<html><head><meta property="og:title" content="Book preview"><meta property="og:description" content="A book worth reading"></head><body>Book</body></html>',
    )
    Jobs.run_immediately!
    post.rebake!
    sign_in(user)
  end

  it "renders standalone mentions as oneboxes and previews inline pills on desktop hover" do
    topic_page.visit_topic(post.topic)
    expect(preview).to have_standalone_card("Book preview")

    preview.hover_pill
    expect(preview).to have_card("Book preview")
    expect(preview).to have_destination("https://example.com/book")
    preview.close
    expect(preview).to have_no_card

    page.refresh
    expect(preview).to have_standalone_card("Book preview")
  end
end
