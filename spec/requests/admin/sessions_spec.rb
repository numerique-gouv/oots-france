require 'rails_helper'

RSpec.describe 'Admin::Sessions' do
  describe 'GET /admin/session/new' do
    it 'offers the form without asking for a session first' do
      get new_admin_session_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css('input[name="password"]')).not_to be_empty
    end

    # The header's navigation belongs to the space, and none of it can be
    # reached from here.
    it 'carries no navigation' do
      get new_admin_session_path

      expect(response.parsed_body.css('.fr-nav')).to be_empty
    end
  end

  describe 'POST /admin/session' do
    let(:administrator) { create(:administrator) }

    it 'opens the space on the right password' do
      post admin_session_path, params: { email: administrator.email, password: administrator.password }

      expect(response).to redirect_to(admin_root_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it 'refuses a wrong password and leaves the space closed' do
      post admin_session_path, params: { email: administrator.email, password: 'un-autre-mot-de-passe' }

      expect(response).to have_http_status(:unprocessable_content)

      get admin_root_path
      expect(response).to redirect_to(new_admin_session_path)
    end

    # `expect` would raise `ParameterMissing` here and answer 400, which is why
    # this controller permits rather than expects.
    it 'shows its error on an empty form rather than failing' do
      post admin_session_path, params: { email: '', password: '' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.css('.fr-alert--error')).not_to be_empty
    end

    # bcrypt handles at most 72 bytes and `authenticate_by` carries no length
    # check of its own, so this is the shape that would raise rather than refuse
    # if the gem ever stopped answering `false` past that limit.
    it 'refuses a password longer than bcrypt accepts rather than failing' do
      post admin_session_path, params: { email: administrator.email, password: 'a' * 300 }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE /admin/session' do
    it 'closes the space again' do
      sign_in

      delete admin_session_path

      expect(response).to redirect_to(new_admin_session_path)

      get admin_root_path
      expect(response).to redirect_to(new_admin_session_path)
    end

    # The flash carries a key, so only a rendered page says whether it resolves.
    it 'says so on the page it lands on' do
      sign_in

      delete admin_session_path
      follow_redirect!

      expect(response.body).to include('Vous êtes déconnecté.')
    end
  end

  # `Administrator.exists?` and not merely a present id in the session: this is
  # the only case that tells the two apart.
  describe 'a session whose account no longer exists' do
    it 'no longer opens the space' do
      administrator = sign_in
      administrator.destroy!

      get admin_root_path

      expect(response).to redirect_to(new_admin_session_path)
    end
  end

  # These cases post the form themselves rather than calling `sign_in`, whose
  # assertion on the root is precisely what they contradict.
  describe 'the page the guard turned away' do
    let(:administrator) { create(:administrator) }

    def sign_in_through_the_form(**smuggled)
      post admin_session_path,
        params: { email: administrator.email, password: administrator.password, **smuggled }
    end

    it 'is where a successful login lands' do
      exchange = create(:exchange, :failed)

      get admin_journal_exchange_path(exchange.exchange_id)
      expect(response).to redirect_to(new_admin_session_path)

      sign_in_through_the_form

      expect(response).to redirect_to(admin_journal_exchange_path(exchange.exchange_id))
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it 'keeps the query string of the page it retains' do
      get admin_journal_root_path(parametre: 'https://exemple.invalid')

      sign_in_through_the_form

      expect(response).to redirect_to(admin_journal_root_path(parametre: 'https://exemple.invalid'))
    end

    # The destination is derived from the request, so a parameter of the login
    # form must not steer it — that is what would make this form an open
    # redirect. `request.fullpath` carries neither scheme nor host, and
    # `action_on_open_redirect` is `:raise` under `load_defaults 8.1`, so a
    # destination naming a host would raise rather than travel; both belts only
    # hold as long as nothing reads a parameter here.
    it 'ignores a destination smuggled in as a request parameter' do
      sign_in_through_the_form(destination: 'https://exemple.invalid')

      expect(response).to redirect_to(admin_root_path)
    end

    it 'is the last one turned away when several were' do
      get admin_journal_root_path
      get admin_common_services_root_path

      sign_in_through_the_form

      expect(response).to redirect_to(admin_common_services_root_path)
    end

    # Replaying the address of an action as a GET would reach a route that does
    # not exist. `DELETE /admin/session` is the one this application answers;
    # GoodJob's retry and discard buttons are the PUT that motivate the rule.
    it 'is not retained when the request the guard refused was not a GET' do
      delete admin_session_path
      expect(response).to redirect_to(new_admin_session_path)

      sign_in_through_the_form

      expect(response).to redirect_to(admin_root_path)
    end

    it 'is the root when the form was opened directly' do
      get new_admin_session_path

      sign_in_through_the_form

      expect(response).to redirect_to(admin_root_path)
    end

    # A refused login renders rather than redirecting, and the guard does not
    # run on `create`: the destination outlives a mistyped password, which is
    # the scenario the whole thing exists for.
    it 'survives a wrong password and serves the attempt that succeeds' do
      get admin_journal_root_path

      post admin_session_path, params: { email: administrator.email, password: 'un-autre-mot-de-passe' }
      expect(response).to have_http_status(:unprocessable_content)

      sign_in_through_the_form

      expect(response).to redirect_to(admin_journal_root_path)
    end

    # The `reset_session` of the login is what forgets it, and it is enough:
    # reaching `destroy` needs a session, which the guard never refuses, so no
    # state holds an authenticated session and a destination at once.
    it 'serves once, and a second login lands on the root again' do
      get admin_journal_root_path
      sign_in_through_the_form
      expect(response).to redirect_to(admin_journal_root_path)

      delete admin_session_path
      sign_in_through_the_form

      expect(response).to redirect_to(admin_root_path)
    end
  end

  # The key travels as a symbol through the flash and is resolved two steps
  # later, by `layouts/_messages`: neither end is a lookup `i18n-tasks` can see.
  it 'says every flash key the space can redirect with' do
    carried = Dir['app/controllers/**/*.rb']
      .flat_map { |path| File.read(path).scan(/:'(admin\.sessions\.[a-z_]+)'/) }
      .flatten.uniq

    expect_said(carried)
  end
end
