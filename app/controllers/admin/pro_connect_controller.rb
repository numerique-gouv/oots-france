module Admin
  # The two addresses the deployment declares to ProConnect. Both answer
  # without a session — the agent is coming back to open or close one — and
  # both redirect rather than render: an authorization code is single use, and
  # leaving in the history a page that carries one invites replaying it.
  class ProConnectController < BaseController
    include ProConnectSession

    skip_before_action :require_administrator

    def retour_connexion
      instance = Settings.proconnect_instance
      return pro_connect_failed([t('controllers.admin.pro_connect.undeclared')]) if instance.nil?

      result = CompleteProConnectSignIn.call(instance:, **returned)
      return admit(result) if result.success?
      return turn_away(result.error) if result.error[:key] == :agent_refused

      pro_connect_failed(result.error[:errors])
    end

    # Both sessions are closed whatever happens here: the Rails one before the
    # browser left, the ProConnect one by the time it comes back. What is left
    # to decide is the page it lands on.
    def retour_deconnexion
      expected = session.delete(:pro_connect_logout).to_h
      return pro_connect_failed([t('controllers.admin.pro_connect.unexpected_logout_state')]) unless logout_state?(expected)
      return redirect_to(expected['france_connect'], allow_other_host: true) if expected['france_connect']

      return show_refusal(expected['refused_email']) if expected['refused_email']

      redirect_to new_admin_session_path, notice: :'admin.sessions.signed_out'
    end

    def admin_section? = false

    private

    # Read before `reset_session`, which takes the destination with the rest of
    # the session — what makes it serve only once. A new session identifier, so
    # that one an attacker managed to plant before the sign-in does not become
    # an authenticated one.
    def admit(result)
      destination = requested_path

      reset_session
      session[:agent_email] = result.agent.email
      session[:pro_connect_id_token] = result.id_token

      redirect_to destination || admin_root_path
    end

    # An address outside the admitted domains opens nothing, and its ProConnect
    # session is ended so that the agent can come back with another one.
    def turn_away(error)
      reset_session

      pro_connect = end_of_pro_connect_session(error[:id_token], refused_email: error[:email])
      return redirect_to(pro_connect, allow_other_host: true) if pro_connect

      show_refusal(error[:email])
    end

    def show_refusal(email)
      session[:pro_connect_refused_email] = email

      redirect_to new_admin_session_path
    end

    # The departure is read once: a second return with the same `state` meets
    # an empty session.
    def returned
      { expected: session.delete(:pro_connect), code: params[:code], state: params[:state],
        announced_error: params[:error], error_description: params[:error_description] }
    end

    def logout_state?(expected)
      expected['state'].present? && ActiveSupport::SecurityUtils.secure_compare(expected['state'], params[:state].to_s)
    end
  end
end
