module Admin
  # Opens the space without ProConnect, in development and test only: the route
  # is drawn in those two environments alone (`config/routes.rb`), and this
  # action refuses anywhere else should it ever be reached.
  #
  # The session it opens is the one a sign-in through ProConnect opens, for an
  # agent of the first admitted domain — the guard admits it as it admits any
  # other, and nothing downstream can tell the two apart.
  class DevelopmentSessionsController < BaseController
    LOCAL_PART = 'administrateur.demonstration'.freeze

    skip_before_action :require_administrator

    def self.agent_email = "#{LOCAL_PART}@#{Settings.proconnect_agent_domains.first}"

    def create
      raise ActionController::RoutingError, 'Not Found' unless Rails.env.local?

      destination = requested_path

      reset_session
      session[:agent_email] = self.class.agent_email

      redirect_to destination || admin_root_path
    end
  end
end
