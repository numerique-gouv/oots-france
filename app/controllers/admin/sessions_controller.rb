module Admin
  # The sign-in page, and the button on it: with the two ProConnect returns and
  # the development entry, what answers without a session. It inherits the guard like every other page and then exempts the two
  # actions that need it, rather than sidestepping `Admin::BaseController`
  # altogether: an action added here later is guarded unless someone says
  # otherwise, which is the right way round.
  class SessionsController < BaseController
    include ProConnectSession
    include EndsFranceConnectSession

    skip_before_action :require_administrator, only: %i[new create]

    def new
      @pro_connect = Settings.proconnect_instance
      @domains = Settings.proconnect_agent_domains
      # Read once: the alert that names a refused agent is said on this page,
      # and only the first time.
      @refused_email = session.delete(:pro_connect_refused_email)
      @development_agent = Agent.demonstration.email if Rails.env.local?
    end

    # The POST of the ProConnect button. The `state` and the `nonce` are kept
    # in the session, which is what ties the return to this departure.
    def create
      instance = Settings.proconnect_instance
      return redirect_to(new_admin_session_path) if instance.nil?

      result = LogLine.speaking { StartProConnectSignIn.call(instance:) }
      return pro_connect_failed(result.error[:errors]) unless result.success?

      session[:pro_connect] = { 'state' => result.state, 'nonce' => result.nonce }
      redirect_to result.authorization_url, allow_other_host: true
    end

    # The operator's session is also the demonstration user's, and ending one
    # ends both: ProConnect first, then the FranceConnect+ session that attested
    # the demonstration identity, if there is one — prepared here from the
    # identity the browser holds, read before `reset_session` empties the
    # session and the identity cookies, and chained on by
    # `Admin::ProConnectController#retour_deconnexion`.
    def destroy
      identity = demo_identity
      id_token = take_id_token

      reset_session

      france_connect = end_of_france_connect_session(identity)
      pro_connect = end_of_pro_connect_session(id_token, france_connect:)
      return redirect_to(pro_connect, allow_other_host: true) if pro_connect

      redirect_to france_connect || new_admin_session_path, allow_other_host: true,
        notice: :'admin.sessions.signed_out'
    end

    # No navigation on the login page: every link it would offer leads somewhere
    # the visitor cannot go yet.
    def admin_section? = false
  end
end
