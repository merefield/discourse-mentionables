# frozen_string_literal: true

module Jobs
  class DestroyMentionableItems < ::Jobs::Base
    def execute(args = {})
      DistributedMutex.synchronize(Mentionables::Source::MUTEX_KEY, validity: 1.hour) do
        MentionableItem.transaction { MentionableItem.destroy_all }
      end
    end
  end
end
