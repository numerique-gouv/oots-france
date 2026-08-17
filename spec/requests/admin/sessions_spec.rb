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
end
