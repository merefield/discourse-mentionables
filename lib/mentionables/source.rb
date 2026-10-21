# frozen_string_literal: true

class ::Mentionables::Source
  REQUIRED_KEYS = %w[url]
  SLUG_PATTERN = /\A[\p{L}\p{N}](?:[\p{L}\p{N}_.-]{0,198}[\p{L}\p{N}])?\z/u
  MUTEX_KEY = "mentionables_catalogue"
  OPTIONAL_KEYS = %w[
    slug
    name
    image_url
    description
    affiliate_snippet_1
    affiliate_snippet_2
    affiliate_snippet_3
  ]
  KEYS = REQUIRED_KEYS + OPTIONAL_KEYS

  def self.build
    selection = { source_class: Mentionables::TopicTable }
    DiscourseEvent.trigger(:mentionables_select_source, selection)
    selection[:source_class].new
  end

  def self.import_columns
    columns = KEYS.dup
    DiscourseEvent.trigger(:mentionables_import_columns, columns)
    columns
  end

  def self.import
    build.import
  end

  attr_accessor :ready

  def initialize(items = nil)
  end

  def ready?
    @ready ||= false
  end

  def import
    if !ready?
      Mentionables::Log.create(
        type: Mentionables::Log.types[:warning],
        source: source_name,
        message: I18n.t("mentionables.import_did_not_start"),
      )
      return nil
    end

    DistributedMutex.synchronize(MUTEX_KEY, validity: 1.hour) do
      @result = Mentionables::ImportResult.new
      items = get_items_from_source
      @result.total = items.size
      raise ArgumentError, I18n.t("mentionables.sync.empty_source") if items.empty?

      validated = items.filter_map { |item| validate_item_hash(item) }
      explicit_slugs = validated.pluck(:slug).compact
      @result.duplicate =
        validated.size - validated.pluck(:url).uniq.size + explicit_slugs.size -
          explicit_slugs.uniq.size
      if validated.size != items.size || @result.duplicate > 0
        @result.error = 1
      else
        synchronize_items(validated)
      end

      Mentionables::Log.create(
        type: Mentionables::Log.types[:report],
        source: source_name,
        message: @result.report,
      )
      @result
    end
  rescue StandardError => error
    Mentionables::Log.create(
      type: Mentionables::Log.types[:error],
      source: source_name,
      message: error.message,
    )
    nil
  end

  protected

  def synchronize_items(items)
    associations = []
    DiscourseEvent.trigger(:mentionables_preload_items, associations)
    existing = MentionableItem.includes(associations).order(:id).group_by(&:url)
    records =
      items.map do |item|
        candidates = existing[item[:url]] || []
        record =
          candidates.find { |candidate| candidate.slug == item[:slug] } || candidates.first ||
            MentionableItem.new
        DiscourseEvent.trigger(:mentionables_prepare_import_item, item, record)
        attributes = KEYS.to_h { |key| [key.to_sym, nil] }.merge(item)
        attributes[:slug] ||= record.slug
        record.assign_attributes(attributes)
        record.populate_metadata
        record
      end
    assign_slugs(records)

    MentionableItem.transaction do
      MentionableItem
        .where.not(id: records.filter_map(&:id))
        .find_each do |record|
          record.destroy!
          @result.deleted += 1
        end

      # Free old slugs inside the transaction so explicit slug swaps remain valid.
      records.each do |record|
        if record.persisted? && record.will_save_change_to_slug?
          MentionableItem.where(id: record.id).update_all(slug: "sync-#{SecureRandom.uuid}")
        end
      end

      records.each do |record|
        if record.new_record?
          @result.created += 1
          record.save!
        elsif record.changed_for_autosave?
          @result.updated += 1
          record.save!
        else
          @result.unchanged += 1
        end
      end

      @result.success = records.size
    end
  end

  def assign_slugs(records)
    assigned = records.filter_map { |record| record.slug.presence }
    if assigned.uniq.size != assigned.size
      raise ArgumentError, I18n.t("mentionables.sync.duplicate_slugs")
    end
    used = assigned.to_set
    records
      .select { |record| record.slug.blank? }
      .sort_by(&:url)
      .each do |record|
        base = record.name.parameterize.first(180).sub(/[^\p{L}\p{N}]+\z/u, "").presence || "item"
        slug = base
        counter = 0
        while used.include?(slug)
          counter += 1
          slug =
            "#{base}-#{Digest::SHA1.hexdigest(record.url).first(12)}#{counter > 1 ? "-#{counter}" : ""}"
        end
        record.slug = slug
        used << slug
      end
  end

  def source_name
    # to be overridden by child class
  end

  def get_items_from_source
    # to be overridden by child class. Should return an array of hashes.
  end

  def validate_item_hash(item)
    item = item.delete_if { |k, v| v.blank? }
    identifier = find_first_required_value(item)

    if REQUIRED_KEYS.any? { |key| !item.has_key?(key.to_sym) }
      add_to_result(:missing_required, identifier)
      return false
    end

    item[:url] = item[:url].to_s.strip
    uri =
      begin
        URI.parse(item[:url])
      rescue URI::InvalidURIError
        nil
      end
    if !uri.is_a?(URI::HTTP) || uri.host.blank? || item[:url].match?(/\s/)
      add_to_result(:invalid_format, identifier)
      return false
    end

    if item[:slug].present? && invalid_slug(item[:slug])
      add_to_result(:invalid_slug, identifier)
      return false
    end

    item
  end

  def add_to_result(key, identifier)
    @result.send("#{key}=", @result.send(key) + 1)

    if identifier.present?
      items = @result.send(:"#{key}_items")
      items.push(identifier)
      @result.send(:"#{key}_items=", items)
    end
  end

  def find_first_required_value(item)
    value = nil

    REQUIRED_KEYS.each do |key|
      if item[key.to_sym].present?
        value = item[key.to_sym]
        break
      end
    end

    value
  end

  def invalid_slug(slug)
    !slug.is_a?(String) || !SLUG_PATTERN.match?(slug)
  end
end
