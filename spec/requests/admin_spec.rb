# frozen_string_literal: true

require_relative "../plugin_helper"

RSpec.describe Mentionables::AdminController do
  fab!(:admin)
  fab!(:user)

  describe "GET /admin/plugins/mentionables/logs.json" do
    it "requires an administrator" do
      get "/admin/plugins/mentionables/logs.json"
      expect(response.status).to eq(404)
      sign_in(user)
      get "/admin/plugins/mentionables/logs.json"
      expect(response.status).to eq(404)
    end

    it "returns logs and item counts" do
      sign_in(admin)
      MentionableItem.create!(slug: "book", name: "Book", url: "https://example.com/book")
      Mentionables::Log.create(
        type: Mentionables::Log.types[:info],
        source: "topic_table",
        message: "Imported",
      )
      get "/admin/plugins/mentionables/logs.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["info"]["total"]).to eq(1)
      expect(response.parsed_body["logs"].first["message"]).to eq("Imported")
    end

    it "treats SQL metacharacters as literal filter text" do
      sign_in(admin)
      Mentionables::Log.create(type: Mentionables::Log.types[:info], message: "Imported")
      get "/admin/plugins/mentionables/logs.json", params: { filter: "' OR 1=1 --" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["logs"]).to eq([])
    end
  end

  describe "POST /admin/plugins/mentionables/logs.json" do
    it "enqueues an import for administrators" do
      sign_in(admin)
      expect { post "/admin/plugins/mentionables/logs.json" }.to change {
        Jobs::ImportMentionableItems.jobs.size
      }.by(1)
      expect(response.status).to eq(200)
    end

    it "rejects regular users" do
      sign_in(user)
      expect { post "/admin/plugins/mentionables/logs.json" }.not_to change {
        Jobs::ImportMentionableItems.jobs.size
      }
      expect(response.status).to eq(404)
    end
  end

  describe "DELETE /admin/plugins/mentionables/logs.json" do
    it "enqueues deletion for administrators" do
      sign_in(admin)
      expect { delete "/admin/plugins/mentionables/logs.json" }.to change {
        Jobs::DestroyMentionableItems.jobs.size
      }.by(1)
      expect(response.status).to eq(200)
    end

    it "rejects regular users" do
      sign_in(user)
      expect { delete "/admin/plugins/mentionables/logs.json" }.not_to change {
        Jobs::DestroyMentionableItems.jobs.size
      }
      expect(response.status).to eq(404)
    end
  end

  describe "GET /site.json" do
    it "shares only imported mention fields from a staff source topic" do
      category = Fabricate(:private_category, group: Group[:staff])
      source_topic =
        Fabricate(:topic, category: category, title: "Private mentionables maintenance")
      Fabricate(
        :post,
        topic: source_topic,
        raw:
          "Private staff notes.\n\n| name | url | slug |\n| --- | --- | --- |\n| Public book | https://example.com/book | public-book |",
      )
      SiteSetting.mentionables_topic_id = source_topic.id
      Jobs::ImportMentionableItems.new.execute
      sign_in(user)

      get "/site.json"

      expect(response.parsed_body["mentionable_items"].first).to include(
        "name" => "Public book",
        "url" => "https://example.com/book",
      )
      expect(response.body).not_to include(source_topic.title)
      get "/t/#{source_topic.id}.json"
      expect(response.status).to eq(404)
    end

    it "exposes only the public mention fields" do
      item =
        MentionableItem.create!(
          slug: "book",
          name: "Book",
          url: "https://example.com/book",
          affiliate_snippet_1: "internal",
        )
      get "/site.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["mentionable_items"]).to eq(
        [
          {
            "id" => item.id,
            "slug" => "book",
            "name" => "Book",
            "url" => item.url,
            "image_url" => nil,
          },
        ],
      )
    end
  end
end
