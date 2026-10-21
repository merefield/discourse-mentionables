# frozen_string_literal: true
Mentionables::Engine.routes.draw do
  get "/logs" => "admin#index", :constraints => AdminConstraint.new
  post "/logs" => "admin#import", :constraints => AdminConstraint.new
  delete "/logs" => "admin#destroy", :constraints => AdminConstraint.new
end

Discourse::Application.routes.draw do
  mount ::Mentionables::Engine, at: "/admin/plugins/mentionables"

  get "/admin/plugins/discourse-mentionables/mentionables" => "admin/admin#index",
      :constraints => AdminConstraint.new
end
