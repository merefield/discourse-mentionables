# frozen_string_literal: true

class MentionableItem < ActiveRecord::Base
  validates :slug,
            presence: true,
            uniqueness: true,
            format: {
              with: Mentionables::Source::SLUG_PATTERN,
            }
  validates :name, presence: true
  validates :url, presence: true, uniqueness: true

  def populate_metadata
    return if url.blank?

    apply_onebox_fallback if name.blank? || SiteSetting.mentionables_onebox_fallback
    self.name = url if name.blank?
  end

  def self.destroy_all
    self.all.destroy_all
    Mentionables::Log.create(type: Mentionables::Log.types[:destroy_all], source: nil)
  end

  def self.remove!(item)
    MentionableItem.where(url: item[:url]).destroy_all
  end

  def apply_onebox_fallback
    preview = Oneboxer.preview(self.url)
    document = Nokogiri.HTML(preview)

    return if document.nil?

    %i[image_url name description].each do |key|
      value = self.send(key)

      if value.blank?
        if key == :image_url
          value = document.at_css(".thumbnail")&.[]("src")
        elsif key == :name
          value = document.at_css("h3")&.text&.strip
        elsif key == :description
          value = document.css("p").text
        end

        self.send("#{key}=", value) if value.present?
      end
    end
  rescue StandardError => error
    Rails.logger.warn("Mentionables metadata lookup failed: #{error.class}")
  end
end

# == Schema Information
#
# Table name: mentionable_items
#
#  id                  :bigint           not null, primary key
#  affiliate_snippet_1 :string
#  affiliate_snippet_2 :string
#  affiliate_snippet_3 :string
#  description         :string
#  image_url           :string
#  name                :string           not null
#  slug                :string
#  url                 :string           not null
#  created_at          :datetime
#  updated_at          :datetime
#
# Indexes
#
#  index_mentionable_items_on_slug  (slug) UNIQUE
#
