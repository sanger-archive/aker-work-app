source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.0.0', '>= 5.0.0.1'
# Use postgresql as the database for Active Record
gem 'pg', '~> 0.18'
# Use Puma as the app server
gem 'puma', '~> 3.0'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

gem 'bootstrap-sass', '~> 3.3.6'
gem 'font-awesome-sass'
gem 'rubocop', '~> 0.41.2', require: false
gem 'wicked'
gem 'bootstrap_form'
gem 'faraday'
gem 'zipkin-tracer'

gem 'json-schema'
gem 'json_api_client', github: 'sanger/json_api_client'

# SSO change - use the
gem 'aker_credentials_gem', github: 'sanger/aker-credentials'

gem 'aker_permission_gem', github: 'sanger/aker-permission'

gem 'aker-study-client', github: 'sanger/aker-study-client'
gem 'aker-set-client', github: 'sanger/aker-set-client'
gem 'matcon_client', github: 'sanger/aker-matcon-client'
gem 'aker_stamp_client', github: 'sanger/aker-stamp-client'

gem "bunny", "= 0.9.0.pre10"

gem 'rswag'
gem 'swagger-ui_rails'

gem 'pry'

gem 'js-routes'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'sqlite3'
end

group :development do
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console'
  gem 'listen', '~> 3.0.5'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]


group :test do
  gem 'webmock'
  gem 'timecop'
end

group :test do
  gem 'cucumber-rails', :require => false
  gem 'rspec-json_expectations'
  # database_cleaner is not required, but highly recommended
end

group :test, :development do
  gem 'launchy'
  gem 'capybara'
  gem 'poltergeist'
  gem 'factory_girl_rails'
  gem 'database_cleaner'
end

gem 'rspec-rails', '~> 3.4'
gem 'simplecov', :require => false, :group => :test
gem 'simplecov-rcov', :group => :test
gem 'rubycritic', :group => :test
