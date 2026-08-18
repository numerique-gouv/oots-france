# What closes the administration space. `Admin::BaseController` includes it, and
# so does GoodJob's own controller: its dashboard is a mounted engine, which no
# filter of this application reaches, and `config/initializers/good_job.rb`
# carries the include there through the load hook the gem offers for it.
module AdminAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_administrator
  end

  private

  def require_administrator
    return if session[:administrator_id] && Administrator.exists?(id: session[:administrator_id])

    # A key and not a message: GoodJob's dashboard renders under `:en`, which it
    # forces for the length of its actions, and this application publishes no
    # English translation — a key of ours resolved there would render as missing.
    # The login page this redirects to is an ordinary request, served under
    # `:fr`, and `layouts/_messages` translates it there.
    #
    # Named through the application's own helpers, because an isolated engine's
    # controller is not given them. `:see_other`, because GoodJob's dashboard
    # submits its retry and discard buttons through the Turbo it ships, and
    # Turbo ignores a redirect that is not a 303 on anything but a GET.
    redirect_to Rails.application.routes.url_helpers.new_admin_session_path,
      alert: :'admin.sessions.connection_required', status: :see_other
  end
end
