# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe MentionableItem do
  it "requires an explicit slug" do
    item = described_class.new(url: "https://example.com/book", name: "A good book")
    expect(item).not_to be_valid
    item.slug = "my-book"
    item.save!
    expect(item.reload.slug).to eq("my-book")
  end

  it "uses plain text from onebox fallbacks" do
    SiteSetting.mentionables_onebox_fallback = true
    Oneboxer.stubs(:preview).returns("<h3><a>A <em>good</em> book</a></h3><p>A description</p>")
    item = described_class.new(url: "https://example.com/book", slug: "book")
    item.populate_metadata
    item.save!
    expect(item.name).to eq("A good book")
    expect(item.description).to eq("A description")
    expect(item.slug).to eq("book")
  end
end
