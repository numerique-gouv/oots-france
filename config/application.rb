require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Both DSFR gems need an explicit `require`: `dsfr/assets` adds the CSS, the
# JS, the fonts and the icons to Propshaft's path, and `dsfr/components` wires
# the `dsfr_*` helpers onto ActionView.
require 'dsfr/assets'
require 'dsfr/components'

module OotsFrance
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = 'Europe/Paris'

    # Everything a human reads lives in `config/locales/fr.yml` and
    # `config/locales/en.yml`, and a page rendered to a browser is read in the
    # one its header's selector chose — `ChosenLanguage`. The messages, the
    # requester's contract and the log stay in the default locale. The OOTS
    # vocabulary that travels in the messages is English and stays in the code —
    # it is not a translation of anything, it is what the specifications name.
    #
    # `rails-i18n` publishes the dates, sizes and plural rules of the declared
    # locales alone, `en.i18n.plural.rule` among them — which GoodJob's
    # dashboard, forcing `:en` for its own rendering, needs as well.
    config.i18n.default_locale = :fr
    config.i18n.available_locales = %i[fr en]

    # The gateway notifies us over HTTP and the work is queued: the queue is a
    # separate process, never the web one.
    config.active_job.queue_adapter = :good_job
    config.good_job.execution_mode = :external
    config.good_job.enable_cron = true
    config.good_job.cron = config_for(:schedule)

    # `app/templates` holds the .xml.erb of the OOTS messages. They are
    # rendered by the builders outside ActionView, so they must not be picked
    # up as autoloadable Ruby.
    config.autoload_paths -= [Rails.root.join('app/templates').to_s]
    config.eager_load_paths -= [Rails.root.join('app/templates').to_s]

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
