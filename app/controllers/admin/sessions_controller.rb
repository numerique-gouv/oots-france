module Admin
  # The one page of the space that answers without a session, and the button on
  # it. It inherits the guard like every other page and then exempts the two
  # actions that need it, rather than sidestepping `Admin::BaseController`
  # altogether: an action added here later is guarded unless someone says
  # otherwise, which is the right way round.
  class SessionsController < BaseController
    include ProConnectSession

    skip_before_action :require_administrator, only: %i[new create]

    # The address a refused agent identified with, read once: the alert that
    # names it is said on this page, and only the first time.
    def new
      @pro_connect = Settings.proconnect_instance
      @domains = Settings.proconnect_agent_domains
      @refused_email = session.delete(:pro_connect_refused_email)
    end

    # The POST of the ProConnect button. The `state` and the `nonce` are kept
    # in the session, which is what ties the return to this departure.
    def create
      instance = Settings.proconnect_instance
      return redirect_to(new_admin_session_path) if instance.nil?

      result = StartProConnectSignIn.call(instance:)
      return pro_connect_failed(result.error[:errors]) unless result.success?

      session[:pro_connect] = { 'state' => result.state, 'nonce' => result.nonce }
      redirect_to result.authorization_url, allow_other_host: true
    end

    # The operator's session is also the demonstration user's, and ending one
    # ends both: ProConnect first, then the FranceConnect+ session that attested
    # the demonstration identity, if there is one — prepared here from what the
    # session holds before `reset_session` takes it, and chained on by
    # `Admin::ProConnectController#retour_deconnexion`.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin`, where `Demo`
    # names the controllers of the demonstration.
    def destroy
      identity = ::Demo::UserIdentity.from_session(session[:demo_identity])
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

    private

    # Nothing to end when no identity was held, and nothing worth failing the
    # sign-out for when the portal cannot be reached: `Demo::EndIdentification`
    # says why. The state is written here rather than there, a session being the
    # controller's to touch.
    #
    # The session of the FranceConnect+ that attested this identity, and of no
    # other: the identity says which one, and a deployment that no longer
    # declares it has none of its own to end.
    #
    # That last case is journalised, where an identity simply absent is not: a
    # session was attested somewhere, and nothing is going to close it. It
    # leaves the same kind of trace as a portal that cannot be reached, which
    # `Demo::EndIdentification` writes for itself — and the operator is signed
    # out either way, so the log is the only place it can be read.
    def end_of_france_connect_session(identity)
      return nil if identity.nil?

      instance = Settings.france_connect_instance(identity.france_connect)
      return undeclared_france_connect(identity) if instance.nil?

      result = ::Demo::EndIdentification.call(identity:, instance:)
      return nil unless result.success?

      session[:france_connect_logout] = result.state

      result.end_session_url
    end

    def undeclared_france_connect(identity)
      Rails.logger.warn(I18n.t('controllers.admin.sessions.france_connect_undeclared',
        name: identity.france_connect))

      nil
    end
  end
end
