# frozen_string_literal: true

module PageObjects
  module Components
    class MentionablePreview < PageObjects::Components::Base
      def hover_pill
        find(".cooked a.mentionable-item", match: :first).hover
      end

      def click_pill
        find(".cooked a.mentionable-item", match: :first).click
      end

      def close
        page.send_keys(:escape)
      end

      def has_card?(title)
        has_css?(".mentionables-preview aside.onebox h3", text: title)
      end

      def has_destination?(url)
        has_css?(".mentionables-preview__visit[href='#{url}']")
      end

      def has_no_card?
        has_no_css?(".mentionables-preview")
      end

      def has_standalone_card?(title)
        has_css?(".cooked > aside.onebox h3", text: title)
      end

      def has_coloured_pill_icon?(icon, colour)
        has_css?(
          ".cooked .mentionable-item > span > svg.mentionables-pro-icon[style*='#{colour}'] use[href='##{icon}']",
        )
      end

      def has_suggestion_icon?(icon)
        has_css?(".ac-mentionable-item-name .mentionables-pro-icon use[href='##{icon}']")
      end
    end
  end
end
