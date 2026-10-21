# frozen_string_literal: true

module PageObjects
  module Pages
    class Mentionables < PageObjects::Pages::Base
      def open
        visit("/admin/plugins/discourse-mentionables/mentionables")
        self
      end

      def has_total?(count)
        has_css?(
          ".mentionables-admin__total",
          text: I18n.t("js.mentionables.info.total", total: count),
        )
      end

      def refresh
        find(".mentionables-refresh").click
      end

      def import
        find(".mentionables-import").click
      end

      def delete_all
        find(".mentionables-delete").click
      end

      def has_message?(key)
        has_css?(".mentionables-admin__message", text: I18n.t("js.mentionables.#{key}").squish)
      end

      def has_log?(title)
        has_css?(".mentionables-admin__logs", text: title)
      end

      def expand_log(title)
        find("summary", text: title, match: :first).click
      end

      def has_details?(text)
        has_css?("details[open]", text: text)
      end

      def has_log_count?(count)
        has_css?(".mentionables-admin__logs tbody tr", count: count)
      end

      def load_more
        find(".mentionables-load-more").click
      end
    end
  end

  module Components
    class MentionableComposer < PageObjects::Components::Composer
      def choose_mention(name)
        find(".ac-mentionable-item a", text: name).click
      end

      def has_suggestion?(name)
        has_css?(".ac-mentionable-item", text: name)
      end

      def has_no_suggestions?
        has_no_css?(".ac-mentionable-item")
      end

      def has_preview_link?(name, url)
        has_css?(".d-editor-preview a.mentionable-item[href='#{url}']", text: name)
      end

      def has_post_code?(text)
        has_css?(".cooked code", text: text)
      end

      def has_post_link?(name, url)
        has_css?(".cooked a.mentionable-item[href='#{url}']", text: name)
      end

      def has_no_mention_button?
        has_no_css?("button.insert-mentionable")
      end

      def has_no_table_button?
        has_no_css?("button.insert-mentionables-table")
      end

      def has_table_skeleton?
        table_has_headers?(".d-editor-preview table")
      end

      def has_rich_table_skeleton?
        table_has_headers?(".ProseMirror table")
      end

      private

      def table_has_headers?(selector)
        %w[name url slug image_url].each_with_index.all? do |column, index|
          has_css?(
            "#{selector} tr:first-child > :nth-child(#{index + 1})",
            text: column,
            exact_text: true,
          )
        end
      end
    end
  end
end
