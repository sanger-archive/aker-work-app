# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

# If relative_url_root is non-nil, use that, otherwise use slash.
map Rails.application.config.relative_url_root || '/' do
  run Rails.application
end
