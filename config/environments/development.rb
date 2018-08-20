Rails.application.configure do
  # NOTE: Settings specified here will take precedence over those in config/application.rb.

  # Verifies that versions and hashed value of the package contents in the project's package.json
  config.webpacker.check_yarn_integrity = true

  config.log_formatter = Logger::Formatter.new
  # Use the lowest log level to ensure availability of diagnostic information when problems arise.
  config.log_level = :debug

  # Verifies that versions and hashed value of the package contents in the project's package.json
  config.webpacker.check_yarn_integrity = false

  # config.relative_url_root = '/work-orders'

  # In the development environment your application's code is reloaded on every request. This slows
  # down response time but is perfect for development since you don't have to restart the web
  # server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  if Rails.root.join('tmp', 'caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs
  config.active_record.verbose_query_logs = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations
  config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  config.action_mailer.delivery_method = :sendmail

  config.study_url = 'http://localhost:3300/api/v1'
  config.study_url_default_proxy = 'http://localhost:3300'

  config.set_url = 'http://localhost:3000/api/v1'
  config.set_url_default_proxy = 'http://localhost:3000'

  config.material_url = 'http://localhost:5000'

  config.stamp_url = 'http://localhost:7000/api/v1'

  config.jwt_secret_key = 'development'

  config.events = {
    enabled: false,
    broker_host: 'localhost',
    broker_port: '5672',
    broker_username: 'work_orders',
    broker_password: 'password',
    vhost: 'aker',
    exchange: 'aker.events.tx',
    catalogues_queue: 'aker_catalogues_q'
  }

  config.job_completion_json = 'job_completion.json'

  config.billing_facade_url = 'http://localhost:3601'

  config.fake_ldap = true

  config.action_mailer.default_url_options = { host: 'localhost', port: 3001 }

  # SSO
  config.default_jwt_user = { email: ENV.fetch('USER', 'user') + '@sanger.ac.uk',
                              groups: ['world'] }

  config.auth_service_url = 'http://localhost:9010'
  config.login_url = config.auth_service_url + '/login'
  config.logout_url = config.auth_service_url + '/logout'

  config.urls = { reception: '',
                  permissions: '',
                  sets: 'http://localhost:3002',
                  projects: '',
                  work: '' }

  config.sequencescape_url = 'http://dev.psd.sanger.ac.uk:6630'

  config.akerdev_email = ENV.fetch('USER', 'user') + '@sanger.ac.uk'
end
