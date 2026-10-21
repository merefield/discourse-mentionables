# frozen_string_literal: true

module Jobs
  class ImportMentionableItems < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args = {})
      return unless SiteSetting.mentionables_enabled

      Mentionables::Source.import
    end
  end
end
