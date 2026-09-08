source 'https://rubygems.org'

ruby '4.0.6'

gem 'rails', '8.1.3.1'

gem 'bcrypt'
gem 'bootsnap', require: false

# json 3.0 dropped the positional options hash from `JSON.parse`, which
# `ActiveSupport::JSON.decode` still passes in 8.1.3.1 — every encrypted cookie,
# and so every session, raises `ArgumentError` on being read. Rails calls it
# with keywords on `8-1-stable`; lift the pin when that ships.
gem 'json', '< 3'
gem 'pg', '~> 1.6'
gem 'propshaft'
gem 'puma', '>= 5.0'
gem 'rails-i18n'
gem 'tzinfo-data', platforms: %i[windows jruby]

# Orchestration: one step per interactor, one sequence per organizer.
gem 'interactor'

# OOTS messages: ERB templates on the way out, XPath on the way in.
gem 'nokogiri'

# Beneficiary token: a JWE encrypted for us, holding a JWT signed by the
# requester. RSA-OAEP-256 / A256GCM.
gem 'jwe'
gem 'jwt'

gem 'faraday'
gem 'faraday-net_http'
gem 'faraday-retry'

gem 'good_job'
# Les transitions légales d'`Exchange`, déclarées plutôt que tenues par l'ordre
# des appels. La gem qu'emploie `data_pass`, dont ce dépôt partage déjà la
# convention interactors / organizers.
gem 'state_machines-activerecord'
gem 'strong_migrations'

# Behaviour attached to the DOM, as Stimulus controllers: two pages of the
# console fetch their listing after loading, which a script hooked on
# `DOMContentLoaded` would never see arrive. `importmap-rails` is what resolves
# `@hotwired/stimulus` without Node and without a bundler.
gem 'importmap-rails'
gem 'stimulus-rails'

gem 'dsfr-view-components'
gem 'pundit'
gem 'view_component'
gem 'wicked'

gem 'logstasher'
gem 'sentry-rails'
gem 'sentry-ruby'

group :development, :test do
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
end

group :development do
  gem 'i18n-tasks', require: false
  gem 'lookbook'
  gem 'rubocop', require: false
  gem 'rubocop-capybara', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
  gem 'web-console'
end

group :test do
  gem 'capybara'
  gem 'cucumber-rails', require: false
  gem 'cuprite'
  gem 'database_cleaner-active_record'
  gem 'shoulda-matchers'
  gem 'state_machines-rspec'
  gem 'simplecov', require: false
  gem 'webmock'

  # `features/support/fake_requester.rb` serves the requester's key set from a
  # `WEBrick::HTTPServer`. Ferrum carried the gem until 0.18, which dropped it.
  gem 'webrick'
end
