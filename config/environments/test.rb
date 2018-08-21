Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.study_url = 'http://external-server:3300/api/v1'
  config.study_url_default_proxy = 'http://external-server:3300'

  config.set_url = 'http://external-server:3000/api/v1'
  config.set_url_default_proxy = 'http://external-server:3000'

  config.material_url = 'http://external-server:5000'

  config.stamp_url = 'http://external-server:7000/api/v1'

  config.billing_facade_url = 'http://external-server:3601'

  config.job_completion_json = 'job_completion.json'


  config.events = {
    enabled: false
  }

  config.fake_ldap = true
  config.jwt_secret_key = 'test'

  config.auth_service_url = 'http://auth_service'
  config.login_url = config.auth_service_url + '/login'
  config.logout_url = config.auth_service_url + '/logout'

  config.urls = { reception: '',
                  permissions: '',
                  sets: 'http://external-server:3002',
                  projects: '',
                  work: '' }

  config.akerdev_email = ENV.fetch('USER', 'user') + '@sanger.ac.uk'

  config.sequencescape_url = 'http://localhost:3000'


end
