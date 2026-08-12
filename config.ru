# This file is used by Rack-based servers to start the application.

require_relative 'config/environment'

# Checked here, and not in an initializer, because the Rake task that renders
# the messages for the Schematron validation runs without a gateway
# configured: a blanket boot check would fail a job that legitimately needs
# none of these. This file is loaded by the web server and by it alone.
Settings.verify! unless Rails.env.test?

run Rails.application
Rails.application.load_server
