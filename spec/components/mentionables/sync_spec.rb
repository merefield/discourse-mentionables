# frozen_string_literal: true

require_relative "../../plugin_helper"

RSpec.describe Mentionables::TopicTable do
  let(:post) { Fabricate(:post) }

  before { SiteSetting.mentionables_topic_id = post.topic_id }

  def source_rows(rows)
    post.update!(
      raw:
        (
          ["| url | name | slug |", "| --- | --- | --- |"] +
            rows.map { |row| "| #{row.join(" | ")} |" }
        ).join("\n"),
    )
  end

  it "updates by URL, creates new URLs, deletes absent URLs, and clears omitted metadata" do
    existing =
      MentionableItem.create!(
        url: "https://example.com/iss",
        name: "Old name",
        slug: "iss",
        image_url: "https://example.com/old.png",
        description: "Old description",
      )
    removed =
      MentionableItem.create!(url: "https://example.com/removed", name: "Removed", slug: "removed")
    source_rows(
      [
        [existing.url, "International Space Station", ""],
        ["https://example.com/new", "New resource", "new"],
      ],
    )

    result = described_class.new.import

    expect(result.report).to include(created: 1, updated: 1, deleted: 1, success: 2)
    expect(existing.reload.attributes).to include(
      "slug" => "iss",
      "name" => "International Space Station",
      "image_url" => nil,
      "description" => nil,
    )
    expect(MentionableItem.where(id: removed.id)).not_to exist
    expect(MentionableItem.pluck(:url)).to contain_exactly(existing.url, "https://example.com/new")
    timestamp = existing.updated_at
    expect(described_class.new.import.report).to include(unchanged: 2, success: 2)
    expect(existing.reload.updated_at).to eq_time(timestamp)
  end

  it "accepts mixed URL-only rows and explicit name and slug overrides" do
    Oneboxer.stubs(:preview).returns("<h3><a>Retrieved title</a></h3><p>Retrieved description</p>")
    source_rows(
      [
        ["https://example.com/auto", "", ""],
        ["https://example.com/name", "Custom name", ""],
        ["https://example.com/slug", "", "iss"],
        ["https://example.com/both", "Both overrides", "both"],
      ],
    )

    expect(described_class.new.import.success).to eq(4)
    expect(MentionableItem.pluck(:url, :name, :slug)).to contain_exactly(
      ["https://example.com/auto", "Retrieved title", "retrieved-title"],
      ["https://example.com/name", "Custom name", "custom-name"],
      ["https://example.com/slug", "Retrieved title", "iss"],
      ["https://example.com/both", "Both overrides", "both"],
    )
    Oneboxer.stubs(:preview).returns("<h3><a>Changed title</a></h3>")
    described_class.new.import
    expect(MentionableItem.find_by(url: "https://example.com/auto").attributes).to include(
      "name" => "Changed title",
      "slug" => "retrieved-title",
    )
  end

  it "uses the URL as a name when a destination has no usable onebox" do
    Oneboxer.stubs(:preview).returns("")
    source_rows([["https://example.com/no-card", "", ""]])

    expect(described_class.new.import.success).to eq(1)
    expect(MentionableItem.first.name).to eq("https://example.com/no-card")
    expect(MentionableItem.first.slug).to be_present
  end

  it "uses one metadata snapshot per import and refreshes it on the next import" do
    SiteSetting.mentionables_onebox_fallback = true
    Oneboxer.stubs(:preview).returns(
      "<h3>First title</h3>",
      '<h3>Updated title</h3><img class="thumbnail" src="https://example.com/new.png"><p>Updated description</p>',
    )
    source_rows([["https://example.com/book", "", ""]])

    expect(described_class.new.import.success).to eq(1)
    item = MentionableItem.first
    expect(item.attributes).to include(
      "name" => "First title",
      "slug" => "first-title",
      "image_url" => nil,
      "description" => nil,
    )

    expect(described_class.new.import.updated).to eq(1)
    expect(item.reload.attributes).to include(
      "name" => "Updated title",
      "slug" => "first-title",
      "image_url" => "https://example.com/new.png",
      "description" => "Updated description",
    )
  end

  it "imports a usable URL when onebox metadata retrieval raises an error" do
    Oneboxer.stubs(:preview).raises(SocketError.new("Destination unavailable"))
    source_rows([["https://example.com/unavailable", "", ""]])

    expect(described_class.new.import.success).to eq(1)
    expect(MentionableItem.first.name).to eq("https://example.com/unavailable")
    expect(MentionableItem.first.image_url).to be_nil
    expect(MentionableItem.first.slug).to be_present
  end

  it "preserves explicit names and thumbnails when automatic metadata retrieval fails" do
    SiteSetting.mentionables_onebox_fallback = true
    Oneboxer.stubs(:preview).raises(SocketError.new("Destination unavailable"))
    post.update!(
      raw:
        "| url | name | image_url |\n| --- | --- | --- |\n| https://example.com/book | My book | https://example.com/cover.png |",
    )

    expect(described_class.new.import.success).to eq(1)
    expect(MentionableItem.first.attributes).to include(
      "name" => "My book",
      "image_url" => "https://example.com/cover.png",
      "slug" => "my-book",
    )
  end

  it "generates distinct slugs for repeated titles without stealing explicit slugs" do
    source_rows(
      [
        ["https://example.com/a", "Book", ""],
        ["https://example.com/b", "Book", ""],
        %w[https://example.com/c Book book],
      ],
    )
    expect(described_class.new.import.success).to eq(3)
    expect(MentionableItem.pluck(:slug).uniq.size).to eq(3)
    expect(MentionableItem.find_by(url: "https://example.com/c").slug).to eq("book")
  end

  it "leaves all records untouched for invalid rows, duplicates, and empty sources" do
    existing =
      MentionableItem.create!(url: "https://example.com/kept", name: "Original", slug: "kept")
    invalid_sets = [
      [[existing.url, "Changed", "kept"], ["", "Missing URL", "missing"]],
      [[existing.url, "Changed", "kept"], %w[javascript:alert(1) Unsafe unsafe]],
      [[existing.url, "Changed", "bad slug"]],
      [[existing.url, "Changed", "one"], [existing.url, "Duplicate URL", "two"]],
      [[existing.url, "Changed", "same"], ["https://example.com/other", "Duplicate slug", "same"]],
      [],
    ]
    invalid_sets.each do |rows|
      source_rows(rows)
      result = described_class.new.import
      expect(result.nil? || result.error?).to eq(true)
      expect(MentionableItem.pluck(:id, :name, :slug, :url)).to eq(
        [[existing.id, "Original", "kept", existing.url]],
      )
    end
  end

  it "generates valid slugs from names with leading and trailing underscores" do
    source_rows(
      [
        ["https://example.com/book", "_book", ""],
        ["https://example.com/guide", "guide_", ""],
        ["https://example.com/empty", "`___`", ""],
        ["https://example.com/long", "_#{"a" * 200}", ""],
      ],
    )

    expect(described_class.new.import.success).to eq(4)
    expect(MentionableItem.pluck(:slug)).to contain_exactly("book", "guide", "item", "a" * 179)
  end

  it "rolls back deletion and updates if an override conflicts with a preserved slug" do
    existing =
      MentionableItem.create!(url: "https://example.com/kept", name: "Original", slug: "kept")
    removed =
      MentionableItem.create!(url: "https://example.com/removed", name: "Removed", slug: "removed")
    source_rows([[existing.url, "Changed", ""], %w[https://example.com/new New kept]])
    expect(described_class.new.import).to be_nil
    expect(existing.reload.name).to eq("Original")
    expect(removed.reload.name).to eq("Removed")
    expect(MentionableItem.count).to eq(2)
  end

  it "rolls back deletions when persistence fails" do
    existing =
      MentionableItem.create!(url: "https://example.com/kept", name: "Original", slug: "kept")
    removed =
      MentionableItem.create!(url: "https://example.com/removed", name: "Removed", slug: "removed")
    source_rows([[existing.url, "Changed", ""]])
    MentionableItem.any_instance.stubs(:save!).raises(StandardError.new("Simulated write failure"))

    expect(described_class.new.import).to be_nil
    expect(existing.reload.name).to eq("Original")
    expect(removed.reload.name).to eq("Removed")
    expect(MentionableItem.count).to eq(2)
  end

  it "consolidates legacy duplicate URLs while retaining the explicitly selected record" do
    existing =
      MentionableItem.create!(url: "https://example.com/book", name: "Original", slug: "original")
    duplicate = existing.dup
    duplicate.slug = "preferred"
    duplicate.save!(validate: false)
    source_rows([[existing.url, "Updated", "preferred"]])

    expect(described_class.new.import.report).to include(updated: 1, deleted: 1)
    expect(MentionableItem.pluck(:id, :name)).to eq([[duplicate.id, "Updated"]])
  end

  it "supports explicit slug swaps and reusing a deleted record's slug" do
    first = MentionableItem.create!(url: "https://example.com/first", name: "First", slug: "first")
    second =
      MentionableItem.create!(url: "https://example.com/second", name: "Second", slug: "second")
    source_rows([[first.url, "First", "second"], [second.url, "Second", "first"]])
    expect(described_class.new.import.updated).to eq(2)
    expect(first.reload.slug).to eq("second")
    expect(second.reload.slug).to eq("first")
    source_rows([%w[https://example.com/replacement Replacement first]])
    expect(described_class.new.import.report).to include(created: 1, deleted: 2)
    expect(MentionableItem.first.slug).to eq("first")
  end
end
