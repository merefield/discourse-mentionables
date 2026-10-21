# frozen_string_literal: true

require_relative "page_objects/mentionables"

RSpec.describe "Manage mentionables" do
  fab!(:admin)
  let(:mentionables) { PageObjects::Pages::Mentionables.new }

  before do
    SiteSetting.mentionables_enabled = true
    sign_in(admin)
  end

  it "lets an administrator import a staff topic table, inspect the report, and delete the data" do
    category = Fabricate(:private_category, group: Group[:staff])
    topic = Fabricate(:topic, category: category)
    source_post =
      Fabricate(
        :post,
        topic: topic,
        raw:
          "| name | url | slug |\n| --- | --- | --- |\n| Example book | https://example.com/book | example-book |\n| Old book | https://example.com/old | old-book |",
      )
    SiteSetting.mentionables_topic_id = topic.id
    Jobs.run_immediately!

    mentionables.open
    expect(mentionables).to have_total(0)
    mentionables.import
    expect(mentionables).to have_message("import_started")
    mentionables.refresh
    expect(mentionables).to have_total(2)
    report_title = I18n.t("js.mentionables.log.report.title")
    mentionables.expand_log(report_title)
    expect(mentionables).to have_details(I18n.t("js.mentionables.log.report.success", count: 2))
    page.refresh
    expect(mentionables).to have_total(2)

    source_post.update!(
      raw:
        "| name | url |\n| --- | --- |\n| Updated book | https://example.com/book |\n| New book | https://example.com/new |",
    )
    mentionables.import
    mentionables.refresh
    mentionables.expand_log(report_title)
    expect(mentionables).to have_details(I18n.t("js.mentionables.log.report.updated", count: 1))
    expect(mentionables).to have_details(I18n.t("js.mentionables.log.report.created", count: 1))
    expect(mentionables).to have_details(I18n.t("js.mentionables.log.report.deleted", count: 1))
    expect(mentionables).to have_total(2)

    source_post.update!(
      raw:
        "| name | url |\n| --- | --- |\n| Valid row | https://example.com/new |\n| Missing URL | |",
    )
    mentionables.import
    mentionables.refresh
    mentionables.expand_log(report_title)
    expect(mentionables).to have_details(I18n.t("js.mentionables.log.report.error"))
    expect(mentionables).to have_total(2)

    mentionables.delete_all
    expect(mentionables).to have_message("data_deleted")
    mentionables.refresh
    expect(mentionables).to have_total(0)
    expect(mentionables).to have_log(I18n.t("js.mentionables.log.destroy_all.title"))
    page.refresh
    expect(mentionables).to have_total(0)
  end

  it "lets an administrator inspect a failed import" do
    Jobs.run_immediately!
    mentionables.open
    mentionables.import
    expect(mentionables).to have_message("import_started")
    mentionables.refresh
    mentionables.expand_log(I18n.t("js.mentionables.log.error.title"))
    expect(mentionables).to have_details(I18n.t("mentionables.topic_table.topic_not_configured"))
  end

  it "lets an administrator load older logs and refresh without duplicates" do
    101.times do |index|
      Mentionables::Log.create(type: Mentionables::Log.types[:info], message: "Import #{index}")
    end
    mentionables.open
    mentionables.load_more
    expect(mentionables).to have_log_count(101)
    mentionables.refresh
    expect(mentionables).to have_log_count(100)
  end
end
