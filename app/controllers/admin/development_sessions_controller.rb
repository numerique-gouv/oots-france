module Admin
  # Opens the space without ProConnect, in development and test only: the route
  # is drawn in those two environments alone (`config/routes.rb`), and this
  # action refuses anywhere else should it ever be reached.
  #
  # The session it opens is the one a sign-in through ProConnect opens, for
  # `Agent.demonstration`: nothing downstream can tell the two apart.
  class DevelopmentSessionsController < BaseController
    skip_before_action :require_administrator

    def create
      raise ActionController::RoutingError, 'Not Found' unless Rails.env.local?

      destination = requested_path

      reset_session
      session[:agent_email] = Agent.demonstration.email

      redirect_to destination || admin_root_path
    end
  end
end
