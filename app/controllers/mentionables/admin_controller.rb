# frozen_string_literal: true
class Mentionables::AdminController < ::Admin::AdminController
  requires_plugin "discourse-mentionables"

  def index
    logs = Mentionables::Log.list(page: params[:page].to_i, filter: params[:filter])

    render_json_dump(
      logs: ActiveModel::ArraySerializer.new(logs, each_serializer: Mentionables::LogSerializer),
      info: Mentionables.info,
    )
  end

  def import
    Jobs.enqueue(:import_mentionable_items)
    render json: success_json
  end

  def destroy
    Jobs.enqueue(:destroy_mentionable_items)
    render json: success_json
  end
end
