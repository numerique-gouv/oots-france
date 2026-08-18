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

      # A new session identifier, so that one an attacker managed to plant
      # before the login does not become an authenticated one.
      reset_session
      session[:administrator_id] = administrator.id

      redirect_to admin_root_path
    end

    def destroy
      reset_session

      redirect_to new_admin_session_path, notice: :'admin.sessions.signed_out'
    end

    # No navigation on the login page: every link it would offer leads somewhere
    # the visitor cannot go yet.
    def admin_section? = false

    private

    # `permit` and not the `expect` used elsewhere: `expect` goes through
    # `require`, which raises on a blank value, so an empty form would answer
    # 400 instead of showing its error. `authenticate_by` returns nothing for a
    # blank password without raising, and equalises the time it takes to answer
    # on an address nobody registered.
    def credentials = params.permit(:email, :password)
  end
end
