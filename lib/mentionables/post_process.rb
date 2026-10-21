# frozen_string_literal: true
module Mentionables::PostProcess
  def self.add_links(doc, post)
    doc
      .css("span.mentionable-item")
      .each do |span|
        slug = span.text[1..]
        item = MentionableItem.find_by(slug: slug)

        if item.present? && item.url.match?(%r{\Ahttps?://}i)
          new_anchor = doc.document.create_element "a"
          new_anchor["href"] = item[:url]
          standalone = standalone?(span)
          new_anchor["class"] = standalone ? "onebox" : "mentionable-item"
          new_anchor["target"] = "_blank"
          new_anchor["rel"] = "nofollow ugc noopener"

          new_span = doc.document.create_element "span"
          new_span.content = item[:name]
          new_anchor.add_child(new_span)

          unless standalone
            new_anchor["data-mentionable-slug"] = item.slug
            DiscourseEvent.trigger(:mentionables_decorate_link, item, new_anchor)
          end

          span.replace new_anchor
        end
      end
  end

  def self.standalone?(span)
    return false if span.parent.name != "p"
    return false if span.ancestors.any? { |node| %w[blockquote li td th].include?(node.name) }

    adjacent = [span.previous_sibling, span.next_sibling]
    directions = %i[previous_sibling next_sibling]
    adjacent.each_with_index.all? do |node, index|
      node = node.public_send(directions[index]) while node&.text? && node.text.strip.empty?
      node.nil? || node.name == "br"
    end
  end
end
