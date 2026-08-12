source 'https://rubygems.org'

ruby '4.0.6'

gem 'rails', '8.1.3.1'

gem 'bootsnap', require: false
gem 'importmap-rails'
gem 'pg', '~> 1.6'
gem 'propshaft'
gem 'puma', '>= 5.0'
gem 'rails-i18n'
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'tzinfo-data', platforms: %i[windows jruby]

# Orchestration : une étape par interacteur, un enchaînement par organisateur.
gem 'interactor'

# Messages OOTS : gabarits ERB en sortie, XPath en entrée.
gem 'nokogiri'

# Jeton bénéficiaire : JWE chiffré pour nous, contenant un JWT signé par le
# requêteur. RSA-OAEP-256 / A256GCM.
gem 'jwe'
gem 'jwt'

gem 'faraday'
gem 'faraday-net_http'
gem 'faraday-retry'

gem 'good_job'
gem 'strong_migrations'

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
  gem 'simplecov', require: false
  gem 'webmock'
end
