require Rails.root.join('spec/support/france_connect_stubs')

# FranceConnect+ as a scenario played in a browser meets it: the same doubles
# `spec/support/france_connect_stubs.rb` serves a request spec, moved onto an
# issuer the browser can reach, plus the one of them that cannot be reused.
module BrowserFranceConnectStubs
  # The address the issuer takes for the length of a scenario. Read off
  # Capybara's own server, which `Capybara::Session#initialize` has already
  # booted — `base_url` is its host and port, and needs no visit first.
  def browser_france_connect_issuer = "#{page.server.base_url}#{BrowserFranceConnect::MOUNT}"

  # Identifies the user in the browser, as a request spec's `identify_demo_user`
  # does in its own session: the departure is clicked, the browser is sent to
  # the authorization endpoint, and it comes back on the return address with a
  # `state` and a `nonce` neither of which the scenario wrote.
  #
  # Also what pins `Settings.oots_france_url`, the root every double of the
  # contract is mounted on — so it is called before them.
  def stub_browser_france_connect(userinfo: FranceConnectStubs::DANISH_USERINFO)
    issuer = browser_france_connect_issuer

    stub_france_connect(userinfo:, issuer:)
    stub_browser_france_connect_tokens(issuer)
  end

  # The button of one card, designated by the FranceConnect+ its form names.
  # Every card carries the same visible label, being the one FranceConnect+
  # gives its European flow, so what tells them apart on the page is the
  # accessible name — and here, the name the form submits.
  def sign_in_with(name)
    page.find(:xpath, "//form[input[@name='france_connect' and @value='#{name}']]")
      .click_button(I18n.t("admin.demo.home.show.france_connect.#{name}.button"))
  end

  # The one double that cannot be shared. The block is evaluated when the
  # application calls, in this same process, so it sees the `nonce` the
  # authorization endpoint has just retained; a body fixed beforehand would have
  # to invent one, and the check tying the return to its departure would then be
  # doubled rather than exercised.
  def stub_browser_france_connect_tokens(issuer)
    stub_request(:post, "#{issuer}#{FranceConnectStubs::PATHS[:token_endpoint]}").to_return do
      claims = france_connect_id_token_claims(iss: issuer, nonce: BROWSER_FRANCE_CONNECT.nonce)

      { body: { access_token: 'un-jeton-d-acces', token_type: 'Bearer', expires_in: 60,
                id_token: sealed_for_procedure(claims) }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    end
  end
end

World(FranceConnectStubs, BrowserFranceConnectStubs)
