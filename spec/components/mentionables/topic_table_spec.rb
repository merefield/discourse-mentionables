# frozen_string_literal: true

require_relative "../../plugin_helper"

RSpec.describe Mentionables::TopicTable do
  it "imports the first matching unquoted table from the current opening post" do
    post = Fabricate(:post, raw: <<~'MD')
      Introductory text.

      ```markdown
      | name | url |
      | --- | --- |
      | Code sample | https://example.com/code |
      ```

      > | name | url |
      > | --- | --- |
      > | Quoted example | https://example.com/quote |

      | notes |
      | --- |
      | An unrelated table |

      | name | url | slug | image_url | description | ignored |
      | --- | --- | --- | --- | --- | --- |
      | **First book** | [Visit](https://example.com/first) | first-book | [Image](https://example.com/first.png) | A book with an escaped \| pipe | Ignore me |
      | Second book | https://example.com/second | | | | |
      | | | | | | |

      Another table follows, but it is not the selected dataset.

      | name | url |
      | --- | --- |
      | Other table | https://example.com/other |
    MD
    post.update_columns(cooked: "<p>Stale cooked content</p>")
    Fabricate(
      :post,
      topic: post.topic,
      raw: "| name | url |\n| --- | --- |\n| Reply | https://example.com/reply |",
    )
    SiteSetting.mentionables_topic_id = post.topic_id

    result = described_class.new.import

    expect(result.success).to eq(2)
    expect(MentionableItem.pluck(:name, :slug, :url, :image_url, :description)).to contain_exactly(
      [
        "First book",
        "first-book",
        "https://example.com/first",
        "https://example.com/first.png",
        "A book with an escaped | pipe",
      ],
      ["Second book", "second-book", "https://example.com/second", nil, nil],
    )
  end

  it "blocks the entire import for invalid rows and duplicate slugs" do
    post = Fabricate(:post, raw: <<~MD)
      | name | url | slug |
      | --- | --- | --- |
      | Book | https://example.com/book | book |
      | Duplicate | https://example.com/duplicate | book |
      | Invalid URL | javascript:alert(1) | invalid |
      | Invalid slug | https://example.com/invalid-slug | bad slug |
      | Missing URL | | missing |
    MD
    SiteSetting.mentionables_topic_id = post.topic_id

    result = described_class.new.import

    expect(result.success).to eq(0)
    expect(result).to be_error
    expect(result.duplicate).to eq(1)
    expect(result.invalid_format).to eq(1)
    expect(result.missing_required).to eq(1)
    expect(result.invalid_slug).to eq(1)
    expect(MentionableItem.count).to eq(0)
  end

  it "rejects unconfigured, missing, deleted, and personal-message topics" do
    deleted = Fabricate(:post)
    deleted.topic.update!(deleted_at: Time.current)
    personal_message = Fabricate(:private_message_post)
    no_opening_post = Fabricate(:topic)

    [
      0,
      Topic.maximum(:id) + 1,
      deleted.topic_id,
      personal_message.topic_id,
      no_opening_post.id,
    ].each do |topic_id|
      SiteSetting.mentionables_topic_id = topic_id
      expect(described_class.new.import).to be_nil
    end
    expect(MentionableItem.count).to eq(0)
    expect(Mentionables::Log.list.size).to eq(5)
  end

  it "reports missing and duplicate column headers" do
    post =
      Fabricate(:post, raw: "| name | URL |\n| --- | --- |\n| Book | https://example.com/book |")
    SiteSetting.mentionables_topic_id = post.topic_id

    expect(described_class.new.import).to be_nil
    expect(Mentionables::Log.list.first.message).to eq(
      I18n.t("mentionables.topic_table.table_not_found"),
    )

    post.update!(
      raw:
        "| name | url | url | slug |\n| --- | --- | --- | --- |\n| Book | https://example.com/book | https://example.com/other | book |",
    )
    expect(described_class.new.import).to be_nil
    expect(Mentionables::Log.list.first.message).to eq(
      I18n.t("mentionables.topic_table.duplicate_columns"),
    )
  end

  it "ignores quoted and fenced tables when there is no source table" do
    post = Fabricate(:post, raw: <<~MD)
      > | name | url |
      > | --- | --- |
      > | Quote | https://example.com/quote |

      ```
      | name | url |
      | --- | --- |
      | Code | https://example.com/code |
      ```
    MD
    SiteSetting.mentionables_topic_id = post.topic_id

    expect(described_class.new.import).to be_nil
    expect(Mentionables::Log.list.first.message).to eq(
      I18n.t("mentionables.topic_table.table_not_found"),
    )
  end
end
