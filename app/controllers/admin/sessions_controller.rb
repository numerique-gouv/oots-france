module Admin
  # The one page of the space that answers without a session. It inherits the
  # guard like every other page and then exempts the two actions that need it,
  # rather than sidestepping `Admin::BaseController` altogether: an action added
  # here later is guarded unless someone says otherwise, which is the right way
  # round.
  class SessionsController < BaseController
    skip_before_action :require_administrator, only: %i[new create]

    def new; end

    def create
      administrator = Administrator.authenticate_by(email: credentials[:email], password: credentials[:password])

      unless administrator
        flash.now[:alert] = :'admin.sessions.refused'

        return render(:new, status: :unprocessable_content)
      end

      # Read here and not after: `reset_session` takes the destination with the
      # rest of the session, which is what makes it serve only once.
      destination = requested_path

      # A new session identifier, so that one an attacker managed to plant
      # before the login does not become an authenticated one.
      reset_session
      session[:administrator_id] = administrator.id

      redirect_to destination || admin_root_path
    end

    # The operator's session is also the demonstration user's, and ending one
    # ends the other: `reset_session` takes the identity with it, and the
    # redirection below ends the FranceConnect+ session that attested it —
    # « pour que FranceConnect+ puisse retrouver la session concernée », the hint being
    # the ID Token decrypted.
    #
    # `::Demo::` and not `Demo::`: this file lives in `Admin`, where `Demo`
    # names the controllers of the demonstration.
    def destroy
      identity = ::Demo::UserIdentity.from_session(session[:demo_identity])

      reset_session

      redirect_to end_of_france_connect_session(identity) || new_admin_session_path,
        allow_other_host: true, notice: :'admin.sessions.signed_out'
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

    # `permit` and not the `expect` used elsewhere: `expect` goes through
    # `require`, which raises on a blank value, so an empty form would answer
    # 400 instead of showing its error. `authenticate_by` returns nothing for a
    # blank password without raising, and equalises the time it takes to answer
    # on an address nobody registered.
    def credentials = params.permit(:email, :password)
  end
end
