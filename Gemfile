source 'https://rubygems.org'

# Force git gems to use secure HTTPS
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

# REST on Rails. Wrap your RESTful web app with Ruby classes and work with them like Active Record
#   models. Read more: https://github.com/rails/activeresource
gem 'bootstrap_form'
gem 'bunny', '= 0.9.0.pre10'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'
gem 'ejs'
gem 'faraday'
gem 'font-awesome-sass'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# Use jquery as the JavaScript library
gem 'jquery-rails'
gem 'js-routes'
gem 'json-schema'
# Pure Ruby LDAP library. Read more: https://github.com/ruby-ldap/ruby-net-ldap
gem 'net-ldap'
gem 'pg'
# Use Puma as the app server
gem 'puma', '~> 3.0'
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 5.0.0', '>= 5.0.0.1'
gem 'rswag'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
gem 'swagger-ui_rails'
# See https://github.com/rails /execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby
# Turbolinks makes navigating your web application faster.
#   Read more: https://github.com/turbolinks/turbolinks
gem 'turbolinks', '~> 5'
# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '~> 3.2'
gem 'wicked'
gem 'zipkin-tracer'

###
# Sanger gems
###
# Add simple support for print-my barcode)
gem 'aker_credentials_gem', github: 'sanger/aker-credentials'
gem 'aker_permission_gem', github: 'sanger/aker-permission'
gem 'aker-set-client', github: 'sanger/aker-set-client'
gem 'aker_stamp_client', github: 'sanger/aker-stamp-client'
gem 'aker-study-client', github: 'sanger/aker-study-client'
gem 'aker-billing-facade-client', github: 'sanger/aker-billing-facade-client'
# Official Sass port of Bootstrap 2 and 3. http://getbootstrap.com/css/#sass
gem 'bootstrap-sass', '~> 3.3.6', github: 'sanger/bootstrap-sass'
gem 'json_api_client', github: 'sanger/json_api_client'
gem 'matcon_client', github: 'sanger/aker-matcon-client'

###
# Groups
###
# Development group
group :development do
  gem 'listen', '~> 3.0.5'
  # An IRB alternative and runtime developer console, https://github.com/pry/pry/
  gem 'pry-rails', '~> 0.3.6'
  # Spring speeds up development by keeping your application running in the background.
  #   Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console'
end

# Test group
group :test do
  gem 'cucumber-rails', require: false
  gem 'pry'
  gem 'rspec-json_expectations'
  gem 'rubycritic'
  # Code coverage for Ruby 1.9+ with a powerful configuration library and automatic merging of
  # coverage across test suites - https://github.com/colszowka/simplecov
  gem 'simplecov', require: false
  # SimpleCov formatter to generate a simple index.html Rcov style
  # https://github.com/fguillen/simplecov-rcov
  gem 'simplecov-rcov'
  gem 'timecop'
end

# Development and test groups
group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'capybara'
  # database_cleaner is not required, but highly recommended
  gem 'database_cleaner'
  gem 'factory_bot_rails'
  gem 'launchy'
  gem 'poltergeist'
  gem 'rspec-rails', '~> 3.4'
  # A Ruby static code analyzer, based on the community Ruby style guide. http://rubocop.readthedocs.io
  gem 'rubocop', '~> 0.51.0', require: false
  gem 'selenium-webdriver'
  gem 'sqlite3'
  gem 'webmock'
  gem 'brakeman', require: false
end
