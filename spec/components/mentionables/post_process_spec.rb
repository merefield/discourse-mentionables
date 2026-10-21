# frozen_string_literal: true

require_relative "../../plugin_helper"

RSpec.describe Mentionables::PostProcess do
  describe ".add_links" do
    it "links exact slugs and escapes names" do
      item =
        MentionableItem.create!(
          slug: "book",
          name: "<img src=x onerror=alert(1)>",
          url: "https://example.com/book",
        )
      doc =
        Nokogiri::HTML5.fragment(
          '<p><span class="mentionable-item">+book</span> <span class="mentionable-item">+unknown</span></p>',
        )
      described_class.add_links(doc, nil)
      expect(doc.at_css("a")["href"]).to eq(item.url)
      expect(doc.at_css("a")["rel"]).to include("noopener")
      expect(doc.at_css("a").text).to eq(item.name)
      expect(doc.css("img")).to be_empty
      expect(doc.at_css("span.mentionable-item").text).to eq("+unknown")
    end

    it "cooks sentence punctuation separately from slugs with internal punctuation" do
      item =
        MentionableItem.create!(
          slug: "example.book-v2",
          name: "Example book",
          url: "https://example.com/book",
        )
      doc = Nokogiri::HTML5.fragment(PrettyText.cook("Read +example.book-v2."))

      described_class.add_links(doc, nil)

      expect(doc.at_css("a")["href"]).to eq(item.url)
      expect(doc.at_css("p").text).to eq("Read Example book.")
    end

    it "leaves unsafe URLs as plain mentions" do
      MentionableItem.create!(slug: "book", name: "Book", url: "javascript:alert(1)")
      doc = Nokogiri::HTML5.fragment('<span class="mentionable-item">+book</span>')
      described_class.add_links(doc, nil)
      expect(doc.css("a")).to be_empty
    end

    it "marks mentions on their own lines for core oneboxing and keeps other mentions inline" do
      MentionableItem.create!(slug: "book", name: "Book", url: "https://example.com/book")
      doc =
        Nokogiri::HTML5.fragment(
          PrettyText.cook(
            "+book\n\nRead +book.\n+book\nMore text.\n\n> +book\n\n- +book\n\n`+book`",
          ),
        )

      described_class.add_links(doc, nil)

      expect(doc.css("a.onebox").map { |anchor| anchor["href"] }).to eq(
        %w[https://example.com/book https://example.com/book],
      )
      expect(doc.css("a.mentionable-item").size).to eq(3)
      expect(doc.at_css("code").text).to eq("+book")
      expect(doc.at_css("a.onebox")["class"]).to eq("onebox")
    end

    it "lets core render its standard onebox template" do
      url = "https://example.com/books/testing"
      MentionableItem.create!(slug: "book", name: "Book", url: url)
      stub_request(:head, url).to_return(status: 200)
      stub_request(:get, url).to_return(
        status: 200,
        headers: {
          "Content-Type" => "text/html",
        },
        body:
          '<html><head><meta property="og:title" content="Testing books"><meta property="og:description" content="A preview supplied by the destination"></head><body>Book</body></html>',
      )
      post = Fabricate(:post, raw: "+book")
      processor = CookedPostProcessor.new(post)

      processor.post_process

      expect(processor.doc.at_css("aside.onebox h3").text).to include("Testing books")
      expect(processor.doc.at_css("aside.onebox").text).to include(
        "A preview supplied by the destination",
      )
      expect(processor.doc.css("a.mentionable-item")).to be_empty
    end
  end
end
