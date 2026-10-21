# frozen_string_literal: true

module ::Mentionables
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace Mentionables
    config.autoload_paths << File.join(config.root, "lib")
    config.eager_load_paths << File.join(config.root, "lib")
  end
end
