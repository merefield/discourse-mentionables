# frozen_string_literal: true

class ::Mentionables::TopicTable < ::Mentionables::Source
  URL_COLUMNS = %w[url image_url].freeze

  def initialize
    super
    @ready = true
  end

  protected

  def source_name
    "topic_table"
  end

  def get_items_from_source
    topic_id = SiteSetting.mentionables_topic_id
    raise ArgumentError, I18n.t("mentionables.topic_table.topic_not_configured") if topic_id.zero?

    topic = Topic.find_by(id: topic_id, deleted_at: nil, archetype: Archetype.default)
    post = topic && Post.find_by(topic_id: topic.id, post_number: 1, deleted_at: nil)
    raise ArgumentError, I18n.t("mentionables.topic_table.post_not_found") unless post

    document =
      Nokogiri::HTML5.fragment(PrettyText.cook(post.raw, user_id: post.user_id, topic_id: topic.id))
    table =
      document
        .css("table")
        .find do |candidate|
          !candidate.ancestors.any? { |ancestor| %w[blockquote table].include?(ancestor.name) } &&
            (REQUIRED_KEYS - headers(candidate)).empty?
        end
    raise ArgumentError, I18n.t("mentionables.topic_table.table_not_found") unless table

    columns = headers(table)
    supported_columns = Mentionables::Source.import_columns
    imported_columns = columns.select { |column| supported_columns.include?(column) }
    if imported_columns.uniq.size != imported_columns.size
      raise ArgumentError, I18n.t("mentionables.topic_table.duplicate_columns")
    end

    table
      .css("tbody > tr")
      .filter_map do |row|
        item = {}
        row
          .element_children
          .select { |cell| cell.name == "td" }
          .each_with_index do |cell, index|
            column = columns[index]
            next if supported_columns.exclude?(column)

            value = cell.text.strip
            if URL_COLUMNS.include?(column)
              value =
                cell.at_css("a[href]")&.[]("href") || cell.at_css("img[src]")&.[]("src") || value
            end
            item[column.to_sym] = value
          end
        item if item.values.any?(&:present?)
      end
  end

  def headers(table)
    table.css("thead > tr > th").map { |cell| cell.text.strip }
  end
end
