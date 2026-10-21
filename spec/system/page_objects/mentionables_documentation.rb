# frozen_string_literal: true

module PageObjects
  module Pages
    class MentionablesDocumentation < PageObjects::Pages::Base
      def prepare_viewport
        page.driver.with_playwright_page do |browser_page|
          browser_page.viewport_size = { width: 1280, height: 960 }
        end
      end

      def has_source_table?
        has_css?(".cooked table tbody tr", count: 3) &&
          has_css?(".cooked table", text: "Community handbook")
      end

      def capture(name)
        return unless ENV["MENTIONABLES_SCREENSHOTS"] == "1"

        directory = File.expand_path("../../../docs/images", __dir__)
        FileUtils.mkdir_p(directory)
        region =
          case name
          when "source-table"
            { x: 300, y: 60, width: 900, height: 390 }
          when "import-report"
            { x: 300, y: 120, width: 970, height: 650 }
          when "onebox-preview"
            { x: 300, y: 60, width: 960, height: 490 }
          when "composer-autocomplete"
            { x: 0, y: 660, width: 1280, height: 300 }
          end
        page.driver.with_playwright_page do |browser_page|
          browser_page.evaluate(<<~JS)
            async () => {
              await document.fonts.ready;
              await Promise.all(Array.from(document.images, (image) => image.decode().catch(() => {})));
            }
          JS
          browser_page.screenshot(
            path: File.join(directory, "#{name}.png"),
            animations: "disabled",
            clip: region,
          )
        end
      end
    end
  end
end
