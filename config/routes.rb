# frozen_string_literal: true
Discourse::Application.routes.append do
  get "/admin/plugins/discourse-mentionables/mentionables" => "admin/admin#index",
      :constraints => AdminConstraint.new
  get "/admin/plugins/mentionables/logs" => "mentionables/admin#index",
      :constraints => AdminConstraint.new
  post "/admin/plugins/mentionables/logs" => "mentionables/admin#import",
       :constraints => AdminConstraint.new
  delete "/admin/plugins/mentionables/logs" => "mentionables/admin#destroy",
         :constraints => AdminConstraint.new
end
