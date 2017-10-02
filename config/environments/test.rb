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
    'Cache-Control' => 'public, max-age=3600'
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false
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

  config.material_url = 'http://external-server:5000/'

  config.stamp_url = 'http://external-server:7000/api/v1'

  config.work_order_completion_json = 'work_order_completion.json'

  config.jwt_secret_key = 'test'
  config.enable_events_sending = false

  config.fake_ldap = true

  config.jwt_exp_time = 2 * 60
  config.jwt_nbf_time = 1 * 60

  config.default_jwt_user = { email: "user@sanger.ac.uk" }

  config.login_url = '#'
  config.logout_url = '#'

end
