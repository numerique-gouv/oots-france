# What closes the administration space. `Admin::BaseController` includes it, and
# so does GoodJob's own controller: its dashboard is a mounted engine, which no
# filter of this application reaches, and `config/initializers/good_job.rb`
# carries the include there through the load hook the gem offers for it.
module AdminAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :require_administrator
    helper_method :signed_in_email, :named_administrator?
  end

  private

  def require_administrator
    return if administrator_signed_in?

    # Derived from the request and never from a parameter, so that the login
    # page cannot be turned into an open redirect. Only a GET: replaying the
    # address of an action as a GET reaches a route that does not exist, and
    # GoodJob's retry and discard buttons are PUT.
    session[:requested_path] = request.fullpath if request.get?

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

  # The agent the sign-in identified, admitted again at every request rather
  # than once at the sign-in: a domain taken out of `DOMAINES_AGENTS_PROCONNECT`
  # closes the sessions it had opened at their next page.
  def administrator_signed_in?
    email = session[:agent_email]

    email.present? && Agent.new(email:).admitted_by?(Settings.proconnect_agent_domains)
  end

  # Declared by the controllers it closes rather than here: the directories and
  # the demonstration stay open to every admitted agent. Redirected rather than
  # rendered in place, for the reason `require_administrator` is — the jobs
  # dashboard renders under `:en`, which this application does not publish.
  def require_named_administrator
    return if named_administrator?

    redirect_to Rails.application.routes.url_helpers.admin_restricted_access_path, status: :see_other
  end

  # Read in the list at every request, so that naming or dismissing an agent in
  # a console takes effect at their next page.
  def named_administrator?
    return @named_administrator if defined?(@named_administrator)

    @named_administrator = administrator_signed_in? && Administrator.appointed?(signed_in_email)
  end

  def requested_path = session[:requested_path]

  # The address of the agent the session admitted, which the header shows.
  def signed_in_email = session[:agent_email]
end
