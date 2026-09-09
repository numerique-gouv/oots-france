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
    # « afin que FranceConnect+ puisse retrouver la session », the hint being
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
    # sign-out for when the portal cannot be reached: the operator is signed out
    # either way, and FranceConnect+ closes its own session on inactivity.
    def end_of_france_connect_session(identity)
      return nil if identity.nil?

      state = SecureRandom.hex(::Demo::StartIdentification::RANDOM_BYTES)
      session[:france_connect_logout] = state

      FranceConnectClient.new.end_session_url(id_token_hint: identity.id_token, state:)
    rescue Faraday::Error, JSON::ParserError, KeyError => e
      Rails.logger.warn(I18n.t('admin.sessions.france_connect_unreachable', error: e.message))
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
