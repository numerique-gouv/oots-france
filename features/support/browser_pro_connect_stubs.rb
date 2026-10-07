require Rails.root.join('spec/support/pro_connect_stubs')

# ProConnect as a scenario played in a browser meets it.
module BrowserProConnectStubs
  # The server Capybara runs for a browser, or the host the in-process driver
  # answers every address on.
  def browser_pro_connect_issuer = "#{page.server&.base_url || Capybara.default_host}#{BrowserProConnect::MOUNT}"

  # The ProConnect the deployment declares, the agent it identifies, and the
  # `/token` double built when the application calls — the `nonce` it signs is
  # the one the departure drew, which the scenario never wrote.
  def stub_browser_pro_connect(email: ProConnectStubs::AGENT_EMAIL)
    issuer = browser_pro_connect_issuer
    stub_pro_connect(email:, issuer:)

    stub_request(:post, "#{issuer}#{ProConnectStubs::PATHS[:token_endpoint]}").to_return do
      claims = pro_connect_id_token_claims(iss: issuer, nonce: BROWSER_PRO_CONNECT.nonce)

      { body: { access_token: 'un-jeton-d-acces', token_type: 'Bearer', expires_in: 60,
                id_token: signed_by_pro_connect(claims) }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end
  end

  def sign_in_without_pro_connect
    visit new_admin_session_path
    click_button I18n.t('admin.sessions.new.development.button')
  end

  # The departure as the login page offers it, and everything that follows on
  # its own: ProConnect, the return, the page the space opens on.
  def sign_in_through_pro_connect(email: ProConnectStubs::AGENT_EMAIL)
    stub_browser_pro_connect(email:)
    visit new_admin_session_path
    find('button.fr-proconnect').click
  end
end

World(ProConnectStubs, BrowserProConnectStubs)
