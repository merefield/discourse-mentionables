# frozen_string_literal: true
class Mentionables::Log
  include ActiveModel::Serialization

  attr_accessor :type, :source, :message, :date

  PAGE_LIMIT = 100

  def initialize(attrs)
    attrs = attrs.with_indifferent_access

    @type = attrs[:type]
    @source = attrs[:source]
    @message = attrs[:message]
  end

  def self.types
    @types ||= Enum.new(info: 1, report: 2, warning: 3, error: 4, destroy_all: 5)
  end

  def self.create(opts)
    log_id = SecureRandom.hex(8)

    PluginStore.set(Mentionables::PLUGIN_NAME, "log_#{log_id}", opts.merge(date: Time.now))
  end

  def self.list_query
    PluginStoreRow.where(
      "
      plugin_name = '#{Mentionables::PLUGIN_NAME}' AND
      key LIKE 'log_%' AND
      (value::json->'date') IS NOT NULL
    ",
    ).order("value::json->>'date' DESC")
  end

  def self.list(page: 0, filter: "")
    list = list_query

    if filter.present?
      list =
        list.where(
          "value::json->>'source' ILIKE :filter OR value::json->>'message' ILIKE :filter",
          filter: "%#{ActiveRecord::Base.sanitize_sql_like(filter)}%",
        )
    end

    list
      .limit(PAGE_LIMIT)
      .offset([page.to_i, 0].max * PAGE_LIMIT)
      .map do |r|
        data = JSON.parse(r.value)
        log = self.new(data)
        log.date = data["date"]
        log
      end
  end
end
