# frozen_string_literal: true
class Mentionables::LogSerializer < ::ApplicationSerializer
  attributes :type, :source, :message, :date

  def type
    Mentionables::Log.types.key(object.type).to_s
  end
end
