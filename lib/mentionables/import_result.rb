# frozen_string_literal: true

class ::Mentionables::ImportResult
  attr_accessor :total,
                :error,
                :missing_required_items,
                :invalid_format_items,
                :invalid_slug_items,
                :success,
                :missing_required,
                :invalid_format,
                :duplicate,
                :failed_to_create,
                :invalid_slug
  attr_accessor :created, :updated, :unchanged, :deleted

  def initialize
    @total = 0

    self.class.types.keys.each { |key| send("#{key}=", 0) }

    @missing_required_items = []
    @invalid_format_items = []
    @invalid_slug_items = []
  end

  def self.types
    @types ||=
      Enum.new(
        success: 0,
        missing_required: 1,
        invalid_format: 2,
        duplicate: 3,
        failed_to_create: 4,
        invalid_slug: 5,
        error: 6,
        created: 7,
        updated: 8,
        unchanged: 9,
        deleted: 10,
      )
  end

  def report
    result = { total: total }

    self.class.types.keys.each do |key|
      if (count = self.send(key)).to_i > 0
        result[key] = count
      end
    end

    %i[missing_required_items invalid_format_items invalid_slug_items].each do |key|
      if (items = self.send(key)).any?
        result[key] = items
      end
    end

    result
  end

  def error?
    error.to_i > 0
  end
end
