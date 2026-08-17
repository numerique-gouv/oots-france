# What closes the administration space. `Admin::BaseController` includes it, and
# so does GoodJob's own controller: its dashboard is a mounted engine, which no
# filter of this application reaches, and `config/initializers/good_job.rb`
# carries the include there through the load hook the gem offers for it.
module AdminAuthentication
  extend ActiveSupport::Concern

  # A literal rather than a locale key. `GoodJob::ApplicationController` wraps
  # every action in an `around_action` that forces the locale to
  # `GoodJob.configuration.dashboard_default_locale` — `:en`, which nothing here
  # configures — whatever the application's own default. A key of ours has no
  # English translation, so it would render as missing on the jobs dashboard and
  # read correctly everywhere else, and the defect would not be seen.
  CONNEXION_REQUISE = 'Cette page demande une connexion.'.freeze

  included do
    before_action :require_administrator
  end

  private

  def require_administrator
    return if session[:administrator_id] && Administrator.exists?(id: session[:administrator_id])

    # Named through the application's own helpers, because an isolated engine's
    # controller is not given them. `:see_other`, because GoodJob's dashboard
    # submits its retry and discard buttons through the Turbo it ships, and
    # Turbo ignores a redirect that is not a 303 on anything but a GET.
    redirect_to Rails.application.routes.url_helpers.new_admin_session_path,
      alert: CONNEXION_REQUISE, status: :see_other
  end
end
