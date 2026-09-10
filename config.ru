# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

# Checked here for the web process, which loads this file and is alone in doing
# so; `config/initializers/verify_settings.rb` reads the same contract for the
# worker, which never loads it. Neither is a blanket boot check: the Rake task
# that renders the messages for the Schematron validation runs without a gateway
# configured, and a check every process ran would fail a job that legitimately
# needs none of these.
Settings.verify! unless Rails.env.test?

run Rails.application
Rails.application.load_server
