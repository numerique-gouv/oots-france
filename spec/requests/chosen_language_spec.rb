require 'rails_helper'

# The language the header's selector chooses, for every page a browser reads.
RSpec.describe 'The chosen language' do
  def page = response.parsed_body

  def selector = page.at_css('header .fr-translate')

  describe 'without a choice' do
    it 'renders the page in French, the selector showing it' do
      get root_path

      expect(page.at_css('html')['lang']).to eq('fr')
      expect(selector.at_css('.fr-translate__btn').text.squish).to eq('FR - Français')
      expect(selector.css('a.fr-translate__language').map { [it.text.squish, it['hreflang'], it['lang']] })
        .to eq([['FR - Français', 'fr', 'fr'], ['EN - English', 'en', 'en']])
      expect(selector.at_css('a[aria-current="true"]').text.squish).to eq('FR - Français')
    end

    it 'offers each language on the address of the page itself' do
      get admin_login_path_with_query

      expect(selector.css('a.fr-translate__language').pluck('href'))
        .to eq(['/admin/session/new?locale=fr&x=1', '/admin/session/new?locale=en&x=1'])
    end
  end

  describe 'choosing English' do
    it 'keeps the choice and sends the browser back to the same address without it' do
      get admin_login_path_with_query(locale: 'en')

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to('/admin/session/new?x=1')
      expect(cookies[:locale]).to eq('en')
    end

    it 'renders the next page in English, the selector showing it' do
      get root_path(locale: 'en')
      follow_redirect!

      expect(page.at_css('html')['lang']).to eq('en')
      expect(selector.at_css('.fr-translate__btn').text.squish).to eq('EN - English')
      expect(selector.at_css('a[aria-current="true"]').text.squish).to eq('EN - English')
      expect(page.at_css('header').text).to include('Administration')
    end

    it 'translates what the DSFR gem writes in French' do
      get root_path(locale: 'en')
      follow_redirect!

      expect(page.at_css('#button-header-menu').text.squish).to eq('Menu')
      expect(page.at_css('.fr-header__menu .fr-btn--close').text.squish).to eq('Close')
    end

    it 'ignores a language it does not offer' do
      get root_path(locale: 'de')

      expect(response).to redirect_to(root_path)
      expect(cookies[:locale]).to be_blank
    end

    # The cookie is not the session, which a sign-in and a sign-out reset.
    it 'outlives the sign-in and the sign-out' do
      get root_path(locale: 'en')
      sign_in
      follow_redirect!
      expect(page.at_css('html')['lang']).to eq('en')

      delete admin_session_path
      get new_admin_session_path
      expect(page.at_css('html')['lang']).to eq('en')
    end

    it 'has the login page translate the flash of the jobs guard in English' do
      get root_path(locale: 'en')
      get admin_jobs_path
      follow_redirect!

      expect(page.at_css('html')['lang']).to eq('en')
      expect(response.body).not_to include('Cette page demande une connexion.')
      expect(response.body).to include(I18n.t('admin.sessions.connection_required', locale: :en))
    end
  end

  # A page rendered in answer to a form has no address of its own: the
  # selector goes back to the page carrying the form.
  describe 'on a page rendered in answer to a form' do
    let(:preview) { create(:preview_session) }
    let(:space) { preview_session_path(preview.specification.segment, preview.token) }

    def answer_the_form(referer:)
      post preview_session_choice_path(preview.specification.segment, preview.token), headers: { 'Referer' => referer }.compact
    end

    def switch_links = selector.css('a.fr-translate__language').pluck('href')

    it 'leads back to the page carrying the form, read off the Referer of this host' do
      answer_the_form(referer: "http://www.example.com#{space}?x=1")

      expect(switch_links).to eq(["#{space}?locale=fr&x=1", "#{space}?locale=en&x=1"])
    end

    it 'never leaves this host for the Referer of another' do
      answer_the_form(referer: "https://elsewhere.example#{space}")

      expect(switch_links).to eq(['/?locale=fr', '/?locale=en'])
    end

    it 'leads to the home page without a Referer, or with one it cannot read' do
      [nil, 'http://www.example.com/a b?%'].each do |referer|
        answer_the_form(referer:)

        expect(switch_links).to eq(['/?locale=fr', '/?locale=en'])
      end
    end
  end

  # The requester's contract answers in the default locale whatever cookie its
  # caller carries.
  it 'leaves the machine entry points out' do
    expect([EvidenceRequestsController, AuthController, DomibusNotificationsController])
      .to all(satisfy { it.ancestors.exclude?(ChosenLanguage) })
  end

  def admin_login_path_with_query(**) = new_admin_session_path(x: 1, **)
end
