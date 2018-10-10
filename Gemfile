# frozen_string_literal: true

source 'https://rubygems.org'

# Force git gems to use secure HTTPS
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

# All the gems not in a group will always be installed:
#   http://bundler.io/v1.6/groups.html#grouping-your-dependencies
gem 'bootstrap_form'
gem 'bunny', '~> 2.9', '>= 2.9.2', require: false
gem 'coffee-rails', '~> 4.2' # Use CoffeeScript for .coffee assets and views
gem 'ejs'
gem 'faraday'
gem 'font-awesome-sass'
gem 'jbuilder', '~> 2.5' # Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jquery-rails' # Use jquery as the JavaScript library
gem 'js-routes'
gem 'json-schema'
gem 'jsonapi-resources'
gem 'lograge'
gem 'logstash-event'
gem 'logstash-logger'
gem 'net-ldap' # Pure Ruby LDAP library. Read more: https://github.com/ruby-ldap/ruby-net-ldap
gem 'pg', '~> 1.0' # https://bitbucket.org/ged/ruby-pg/issues/270/pg-100-x64-mingw32-rails-server-not-start
gem 'pry'
gem 'puma', '~> 3.0' # Use Puma as the app server
gem 'rack-cors'
gem 'rails', '~> 5.2' # Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'react-rails'
gem 'request_store'
gem 'rswag-api'
gem 'rswag-ui'
gem 'sass-rails', '~> 5.0' # Use SCSS for stylesheets
gem 'swagger-ui_rails'
gem 'therubyracer', platforms: :ruby # See https://github.com/rails /execjs#readme for more
gem 'turbolinks', '~> 5' # Turbolinks makes navigating your web application faster.
gem 'uglifier', '~> 3.2' # Use Uglifier as compressor for JavaScript assets
gem 'uuid'
gem 'webpacker', '~> 3.2'
gem 'webpacker-react', '~> 0.3.2'
gem 'wicked'
gem 'health_check'
gem 'bootsnap'
gem 'draper'

###
# Sanger gems
###
gem 'aker-billing-facade-client', github: 'sanger/aker-billing-facade-client'
gem 'aker_credentials_gem', github: 'sanger/aker-credentials'
gem 'aker_permission_gem', github: 'sanger/aker-permission'
gem 'aker-set-client', github: 'sanger/aker-set-client'
gem 'aker_stamp_client', github: 'sanger/aker-stamp-client'
gem 'aker-study-client', github: 'sanger/aker-projects-client-gem'
gem 'aker_shared_navbar', github: 'sanger/aker-shared-navbar'
gem 'bootstrap-sass', '~> 3.3.6', github: 'sanger/bootstrap-sass'
gem 'json_api_client', github: 'sanger/json_api_client'
gem 'matcon_client', github: 'sanger/aker-matcon-client'

###
# Groups
###
group :development, :test do
  gem 'brakeman', require: false
  gem 'byebug', platform: :mri # Call 'byebug' anywhere in the code to get a debugger console
  gem 'capybara'
  gem 'database_cleaner' # database_cleaner is not required, but highly recommended
  gem 'factory_bot_rails'
  gem 'launchy'
  gem 'poltergeist'
  gem 'rspec-rails', '~> 3.4'
  gem 'rswag-specs'
  gem 'selenium-webdriver'
  gem 'webmock'
end

group :development do
  gem 'listen', '~> 3.0.5'
  gem 'pry-rails', '~> 0.3.6' # An IRB alternative and runtime developer console
  gem 'rubocop', '~> 0.51.0', require: false # A Ruby static code analyzer
  gem 'spring' # Spring speeds up development by keeping your application running in the background
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'web-console' # Access an IRB console on exception pages or by using <%= console %>
end

group :test do
  gem 'rspec-json_expectations'
  gem 'rubycritic'
  gem 'simplecov', require: false # Code coverage for Ruby 1.9+
  gem 'simplecov-rcov' # SimpleCov formatter to generate a simple index.html Rcov style
  gem 'timecop'
end
