require 'rails_helper'

# The dashboard is a mounted engine: none of this application's filters apply
# to it, and only a real request proves it is wired in at all.
RSpec.describe 'Admin::Jobs' do
  describe 'GET /admin/jobs' do
    it 'serves the GoodJob dashboard' do
      sign_in

      get admin_jobs_path
      follow_redirect! while response.redirect?

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('GoodJob')
    end

    # The engine carries no filter of ours: the guard reaches it only through the
    # load hook of `config/initializers/good_job.rb`, and nothing else in the
    # suite would notice that hook gone. The 303 is asserted because GoodJob's
    # own Turbo drops a redirect that is not one on its retry and discard
    # buttons, and `redirect_to` alone would not see the difference.
    it 'sends a visitor with no session to the login page' do
      get admin_jobs_path

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(login_path)

      follow_redirect!
      expect(response.body).not_to include('GoodJob')

      # The guard runs inside GoodJob's `around_action`, which renders under
      # `:en`: the flash carries a key rather than a message, and this login
      # page — an ordinary request — is what translates it.
      expect(response.body).to include('Cette page demande une connexion.')
    end

    # The dashboard is where `request.fullpath` is least obvious: the guard runs
    # inside the engine, and what it retains is the address the engine was
    # reached at — trailing slash included, which this application's own helper
    # leaves out. Followed to the end rather than merely compared, since the
    # point is that the address still opens the dashboard.
    it 'is where the login lands once the dashboard turned a visitor away' do
      get admin_jobs_path

      administrator = create(:administrator)
      post Rails.application.routes.url_helpers.admin_session_path,
        params: { email: administrator.email, password: administrator.password }

      expect(response).to redirect_to("#{admin_jobs_path}/")

      follow_redirect! while response.redirect?
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('GoodJob')
    end
  end

  # A gem upgrade that renamed or dropped the hook would leave
  # `ActiveSupport.on_load` waiting for a name nobody fires: no error at boot,
  # none at request time, and the dashboard public again. The request above goes
  # red too, but through routing and redirection, so it names the symptom rather
  # than the cause.
  it 'carries the guard into the engine controller' do
    expect(GoodJob::ApplicationController.ancestors).to include(AdminAuthentication)
  end

  # Once a request has reached the mounted engine, this spec's own
  # `new_admin_session_path` is resolved against the engine's mount point and
  # yields `/admin/jobs/admin/session/new`. The application's route helpers,
  # which is what the guard redirects through, are not narrowed that way.
  def login_path = Rails.application.routes.url_helpers.new_admin_session_path
end
