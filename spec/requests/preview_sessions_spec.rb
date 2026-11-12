require 'rails_helper'

RSpec.describe 'The preview space' do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  let!(:session) { create(:preview_session) }
  let(:page) { response.parsed_body }

  # The segment of the line the session was issued for, which every address of
  # the space carries.
  def segment = session.specification.segment

  def visit_space(token = session.token, params: {}) = get(preview_session_path(segment, token), params:)

  def space_path(params = {}) = preview_session_path(segment, session.token, params)

  def identify(params = {}, **) = identify_in_preview_space(space_path(params), **)

  describe 'a first visit within T2' do
    before do
      identify
      visit_space
    end

    # CA7: no operator session, who asks and for what, the document offered.
    it 'shows who asks for which document, and offers it' do
      expect(response).to have_http_status(:ok)
      expect(page.text).to include('Requêteur de test')
      link = page.at_css("a[href='#{preview_session_document_path(segment, session.token)}']")

      expect(link).to have_attributes(attributes: include('target', 'rel', 'title'))
      expect([link['target'], link['rel'], link['download']]).to eq(['_blank', 'noopener', nil])
      expect(link['title']).to end_with('nouvelle fenêtre')
    end

    it 'shows the pre-production badge of the site in its header' do
      expect(page.at_css('.fr-header__service-title .fr-badge').text).to eq('Préproduction')
      expect(page.at_css('.fr-header__service-tagline').text.squish)
        .to eq('Échange de justificatifs entre administrations européennes')
    end

    # CA7 and CA8: two radio buttons and nothing to type.
    it 'asks for a decision and nothing else' do
      expect(page.css('input[type=radio]').pluck('value')).to eq(PreviewSession::DECISIONS)
      expect(page.css('input:not([type=radio]):not([type=hidden]):not([type=submit]), textarea, select')).to be_empty
    end

    # CA26: chapter 4.8 §3.2, the URL visited — the visit before the
    # identification as much as the one after.
    it 'journals the visit with the address visited' do
      expect(AuditEvent.where(event_type: 'preview_visited').pluck(:exchange_id, :preview_location))
        .to eq([[session.exchange_id, "http://www.example.com#{space_path}"]] * 2)
    end
  end

  # CA8: the document offered is the one the answer will carry.
  it 'serves the very document it keeps' do
    identify
    get preview_session_document_path(segment, session.token)

    expect(response.media_type).to eq('application/pdf')
    expect(response.headers['Content-Disposition']).to start_with('inline')
    expect(response.body).to eq(session.document_bytes)
  end

  # CA9: once the choice is made, the document is no longer served.
  it 'no longer serves the document once the choice is made' do
    identify
    session.decide!(accepted: true)
    get preview_session_document_path(segment, session.token)

    expect(response).to have_http_status(:not_found)
  end

  # CA10: an address France did not issue says nothing of any request.
  it 'says an unknown link is no longer valid' do
    visit_space('inconnu')

    expect(response).to have_http_status(:not_found)
    expect(page.at_css('h1').text).to eq(I18n.t('preview_sessions.show.invalid.title'))
    expect(page.text).not_to include('Requêteur de test')
  end

  # CA12 of OOTS-237: the same UUID under the segment of the other line is an
  # address France did not issue, and says nothing of the request either.
  describe 'the segment of the line' do
    let!(:session) { create(:preview_session, :legacy_line) }

    it 'says the link is no longer valid under the segment of the other line' do
      get preview_session_path('v2.0', session.token)

      expect(response).to have_http_status(:not_found)
      expect(page.at_css('h1').text).to eq(I18n.t('preview_sessions.show.invalid.title'))
      expect(page.text).not_to include('Requêteur de test')
    end

    it 'serves the space under the segment it was issued with, and nothing else under the other' do
      identify
      get preview_session_path('v1.2', session.token)
      expect(response).to have_http_status(:ok)
      expect(session.location).to end_with("/previsualisation/v1.2/#{session.token}")

      get preview_session_document_path('v2.0', session.token)
      expect(response).to have_http_status(:not_found)
    end
  end

  it 'says the delay ran out past T2' do
    travel(17.minutes) { visit_space }

    expect(page.at_css('h1').text).to eq(I18n.t('preview_sessions.show.expired.title'))
  end

  describe 'the choice' do
    before { identify }

    def choose(choice) = post(preview_session_choice_path(segment, session.token), params: { choice: })

    # CA12, and article 17(2): the decision is logged, the interaction ends.
    it 'records the decision and stops offering one' do
      choose('accepted')
      follow_redirect!

      expect(session.reload.decision).to eq('accepted')
      expect(AuditEvent.find_by(event_type: 'preview_decided').detail).to eq('accepted')
      expect(response.parsed_body.css('input[type=radio]')).to be_empty
    end

    it 'records nothing once the link has run out' do
      travel(17.minutes) { choose('accepted') }

      expect(session.reload.decision).to be_nil
      expect(AuditEvent.where(event_type: 'preview_decided')).to be_empty
    end

    # Without JavaScript the button is active: the server says what is missing.
    it 'refuses an empty choice, and says so' do
      choose('')

      expect(response).to have_http_status(:unprocessable_content)
      expect(page.css('.fr-message--error')).to be_present
    end

    # CA16: the second request waiting, the answer goes by job.
    it 'answers a second request already waiting' do
      session.hold!(raw: '<second/>', sent_at: Time.current,
        message_id: 'second', answering: nil, return_location: 'https://portail.example/retour')

      expect { choose('refused') }.to have_enqueued_job(AnswerPreviewedRequestJob).with(session.id)
    end

    # CA16 on 2.0: the way back once the second request has come, not before.
    it 'waits for the second request before offering the way back, then takes it' do
      choose('accepted')
      visit_space

      expect(page.text).to include(I18n.t('preview_sessions.return.awaiting'))
      session.update!(return_location: 'https://portail.example/retour')
      get preview_session_return_path(segment, session.token)

      zone = response.parsed_body.at_css('[data-controller=preview-return]')
      expect(zone.at_css('a')['href']).to eq('https://portail.example/retour')
      expect(zone['data-preview-return-follow-value']).to eq('true')
    end

    # The choice made and the way back known, the space has nothing more to
    # say: it sends the user back, from the choice as from a later visit.
    it 'sends the user straight back to the procedure once the way is known' do
      session.hold!(raw: '<second/>', sent_at: Time.current,
        message_id: 'second', answering: nil, return_location: 'https://portail.example/retour')

      choose('accepted')
      expect(response).to redirect_to('https://portail.example/retour')
      expect(response).to have_http_status(:see_other)

      visit_space
      expect(response).to redirect_to('https://portail.example/retour')
    end
  end

  # OOTS-287 RG3 and RG5: no document matches the user, who reads so once
  # recognised, and is offered nothing to choose.
  describe 'an address no document matches' do
    let!(:session) { create(:preview_session, :unmatched) }

    def heading = page.at_css('h1').text

    it 'says to the recognised user that no document matches them, naming who asks and for what' do
      identify
      visit_space

      expect(response).to have_http_status(:ok)
      expect(heading).to eq('Aucun document ne vous correspond')
      expect(page.text).to include('Requêteur de test')
      expect(page.css('input[type=radio], a[href$="/document"]')).to be_empty
      expect(page.text).to include(I18n.t('preview_sessions.return.awaiting'))
      expect(session.reload.status).to eq('decided')
    end

    it 'speaks the language the header chose' do
      identify
      get preview_session_path(segment, session.token, locale: 'en')
      follow_redirect! if response.redirect?

      expect(heading).to eq('No document matches you')
      expect(page.text).not_to include('Confirm my choice')
    end

    it 'offers the way back as a button, without taking it' do
      session.hold!(raw: '<second/>', sent_at: Time.current, message_id: 'second', answering: nil,
        return_location: 'https://portail.example/retour')
      identify

      expect { visit_space }.to have_enqueued_job(AnswerPreviewedRequestJob).with(session.id)
      expect(response).to have_http_status(:ok)
      zone = page.at_css('[data-controller=preview-return]')
      expect(zone.at_css('a.fr-btn')['href']).to eq('https://portail.example/retour')
      expect(zone['data-preview-return-follow-value']).to eq('false')
    end

    it 'keeps saying so once answered, without naming who asked' do
      identify
      visit_space
      session.reload.update!(return_location: 'https://portail.example/retour')
      session.conclude!
      expect { visit_space }.not_to have_enqueued_job(AnswerPreviewedRequestJob)

      expect(heading).to eq('Aucun document ne vous correspond')
      expect(page.text).to include(I18n.t('preview_sessions.show.unmatched.concluded'))
      expect(page.text).not_to include('Requêteur de test')
      expect(page.at_css('a.fr-btn')['href']).to eq('https://portail.example/retour')
    end

    it 'serves no document, and takes no decision' do
      identify
      get preview_session_document_path(segment, session.token)
      expect(response).to have_http_status(:not_found)

      post preview_session_choice_path(segment, session.token), params: { choice: 'accepted' }
      expect(session.reload.decision).to be_nil
      expect(AuditEvent.where(event_type: 'preview_decided')).to be_empty
    end

    describe 'on the 1.2 line' do
      let!(:session) { create(:preview_session, :unmatched, :legacy_line) }

      it 'offers the way back the visit brought' do
        identify({ returnurl: 'https://portail.example/retour' })
        visit_space

        expect(page.at_css('a.fr-btn')['href']).to eq('https://portail.example/retour')
      end
    end
  end

  describe 'the 1.2 line' do
    let!(:session) { create(:preview_session, :legacy_line) }

    before { identify }

    # CA17: the way back comes with the visit, offered as soon as the choice is made.
    it 'sends the user back by the way the visit brought, as soon as the choice is made' do
      visit_space(params: { returnurl: 'https://portail.example/retour', returnmethod: 'GET' })
      post preview_session_choice_path(segment, session.token), params: { choice: 'accepted' }

      expect(response).to redirect_to('https://portail.example/retour')
    end

    # Chapter 4.9 v1.2.3 §5: another method than GET is followed by a form
    # with an empty body.
    it 'offers the way back as a form when the visit asked for POST' do
      visit_space(params: { returnurl: 'https://portail.example/retour', returnmethod: 'post' })
      post preview_session_choice_path(segment, session.token), params: { choice: 'refused' }
      follow_redirect!

      form = response.parsed_body.at_css("form[action='https://portail.example/retour']")
      expect(form['method']).to eq('post')
      expect(form['data-preview-return-target']).to eq('way')
      expect(form.css('input')).to be_empty
      expect(AuditEvent.find_by(event_type: 'preview_decided').detail).to eq('refused')
    end

    # Once the choice is made, a later visit no longer moves the way back the
    # page offers.
    it 'keeps the way back once the choice is made' do
      visit_space(params: { returnurl: 'https://portail.example/retour' })
      post preview_session_choice_path(segment, session.token), params: { choice: 'accepted' }
      visit_space(params: { returnurl: 'https://ailleurs.example/' })

      expect(session.reload.return_location).to eq('https://portail.example/retour')
    end

    it 'falls back on GET for a method chapter 4.9 does not name' do
      visit_space(params: { returnurl: 'https://portail.example/retour', returnmethod: 'DELETE' })

      expect(session.reload.return_method).to eq('GET')
    end

    # CA18: no safe way back, a warning, and the decision all the same.
    it 'warns a user who came without a safe way back' do
      allow(Settings).to receive(:oots_france_url).and_return('https://oots.example')
      visit_space(params: { returnurl: 'http://portail.example/retour' })

      expect(page.css('.fr-alert--warning')).to be_present
      expect(page.css('input[type=radio]').size).to eq(2)
    end
  end

  # The user identifies again before anything of the request is shown
  # (chapter 4.9 §2, steps 15-20).
  describe 'the identity check' do
    def page_title = response.parsed_body.at_css('h1').text

    # CA1: to the declared FranceConnect+, European flow, substantial level,
    # back to the space's own address — and nothing of the request first.
    it 'sends an unidentified visitor to FranceConnect+ before naming anything' do
      stub_france_connect
      visit_space

      departure = URI.parse(response.headers['Location'])
      query = URI.decode_www_form(departure.query).to_h
      expect("#{departure.scheme}://#{departure.host}#{departure.path}")
        .to eq(FranceConnectStubs::AUTHORIZATION_ENDPOINT)
      expect(query).to include('acr_values' => 'eidas2', 'idp_hint' => 'eidas-bridge',
        'redirect_uri' => "#{FranceConnectStubs::PROCEDURE_URL}/previsualisation_franceconnect/retour_connexion")
      expect(response.body).not_to include('Requêteur de test')
    end

    # The real FranceConnect+ wherever the deployment declares it, and no
    # choice offered.
    it 'sends to the real FranceConnect+ once the deployment declares it' do
      stub_france_connect
      stub_real_france_connect
      visit_space

      expect(response.headers['Location']).to start_with(FranceConnectStubs::REAL_AUTHORIZATION_ENDPOINT)
    end

    # CA1: neither the document, nor the choice, nor the way back.
    it 'serves an unidentified visitor nothing of the request' do
      session.update!(first_visited_at: Time.current, return_location: 'https://portail.example/retour')

      get preview_session_document_path(segment, session.token)
      expect(response).to have_http_status(:not_found)
      post preview_session_choice_path(segment, session.token), params: { choice: 'accepted' }
      expect(response).to have_http_status(:not_found)
      get preview_session_return_path(segment, session.token)
      expect(response).to have_http_status(:not_found)
      expect(session.reload.decision).to be_nil
    end

    # CA2 and CA7: the person of the request, the decision page, and no second
    # round trip at the next visit.
    it 'opens the decision page to the person of the request, and remembers them' do
      identify
      expect(response).to redirect_to(space_path)

      visit_space
      expect(page.css('input[type=radio]').size).to eq(2)
      expect(AuditEvent.find_by(event_type: 'preview_identified').detail).to eq('confirmed')
    end

    it 'ignores case, outer blanks and the Unicode form' do
      identify(userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('family_name' => ' DUPONT ',
        'given_name' => "sophie\u0301".unicode_normalize(:nfd).delete("\u0301")))
      visit_space

      expect(page_title).to eq(I18n.t('preview_sessions.show.open.title'))
    end

    # CA3 and CA9: another person sees no document, the address is concluded,
    # and the journal keeps the outcome and nothing of who came.
    it 'refuses someone else, concludes the address, and journals only the outcome' do
      identify(userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('birthdate' => '1965-11-26'))
      visit_space

      expect(page_title).to eq(I18n.t('preview_sessions.show.refused.title'))
      expect(page.css('input[type=radio]')).to be_empty
      expect(session.reload).to have_attributes(status: 'failed', identification: 'mismatched')
      event = AuditEvent.find_by(event_type: 'preview_identified')
      expect(event.detail).to eq('mismatched')
      expect(event.attributes.values.join).not_to include('1965-11-26')
      get preview_session_document_path(segment, session.token)
      expect(response).to have_http_status(:not_found)
    end

    # CA5: FranceConnect+ coming back with an error, or a level below eidas2.
    it 'refuses an identification FranceConnect+ declined' do
      stub_france_connect
      visit_space
      state = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h.fetch('state')
      get preview_franceconnect_retour_connexion_path, params: { error: 'access_denied', state: }

      expect(session.reload).to have_attributes(status: 'failed', identification: 'unauthenticated')
      expect(AuditEvent.find_by(event_type: 'preview_identified').detail).to eq('unauthenticated')
    end

    it 'refuses a level below the substantial one' do
      identify(acr: 'eidas1')

      expect(session.reload.identification).to eq('unauthenticated')
    end

    # CA6: a revisit, from any browser, says so and sends nobody to identify.
    it 'says the evidence cannot be provided at a revisit, without a second identification' do
      identify(userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('birthdate' => '1965-11-26'))
      reset!
      visit_space

      expect(response).to have_http_status(:ok)
      expect(page_title).to eq(I18n.t('preview_sessions.show.refused.title'))
    end

    # CA3 and CA4 on 2.0: the second request waiting is answered at once.
    it 'answers the second request already waiting' do
      session.hold!(raw: '<second/>', sent_at: Time.current,
        message_id: 'second', answering: nil, return_location: 'https://portail.example/retour')

      expect { identify(userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('birthdate' => '1965-11-26')) }
        .to have_enqueued_job(AnswerPreviewedRequestJob).with(session.id)
    end

    # On 2.0, the way back once the second request has come, offered and not
    # followed — the user reads the refusal first.
    it 'offers the way back once known, without taking it' do
      identify(userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('birthdate' => '1965-11-26'))
      visit_space
      expect(page.text).to include(I18n.t('preview_sessions.return.awaiting'))

      session.update!(return_location: 'https://portail.example/retour')
      get preview_session_return_path(segment, session.token)

      zone = response.parsed_body.at_css('[data-controller=preview-return]')
      expect(zone['data-preview-return-follow-value']).to eq('false')
      expect(zone.at_css('a')['href']).to eq('https://portail.example/retour')
    end

    # A check failed by another browser after the user decided does not undo
    # the decision, and shows that browser no way back of theirs.
    it 'leaves a decided address be, and shows another browser no way back' do
      identify
      post preview_session_choice_path(segment, session.token), params: { choice: 'accepted' }
      session.update!(return_location: 'https://portail.example/retour')
      reset!
      identify(userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('birthdate' => '1965-11-26'))
      visit_space

      expect(session.reload).to have_attributes(status: 'decided', identification: nil)
      expect(page_title).to eq(I18n.t('preview_sessions.show.refused.title'))
      expect(page.text).not_to include('portail.example')
    end

    # A return carrying another `state` — a forged link, another tab's
    # departure — neither consumes the departure nor concludes the address.
    it 'refuses a return whose state is not the departure\'s, and leaves the address open' do
      stub_france_connect
      visit_space
      state = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h.fetch('state')
      get preview_franceconnect_retour_connexion_path, params: { error: 'access_denied', state: 'forge' }

      expect(response).to have_http_status(:bad_request)
      expect(session.reload).to have_attributes(status: 'pending', identification: nil)
      expect(AuditEvent.where(event_type: 'preview_identified')).to be_empty

      get preview_franceconnect_retour_connexion_path, params: { error: 'access_denied', state: }
      expect(session.reload.identification).to eq('unauthenticated')
    end

    it 'refuses a return replayed after the departure was spent' do
      departure = identify
      get preview_franceconnect_retour_connexion_path, params: { code: 'un-code', state: departure.fetch('state') }

      expect(response).to have_http_status(:bad_request)
      expect(AuditEvent.where(event_type: 'preview_identified').count).to eq(1)
    end

    # FranceConnect+ unreachable at the exchange of the code: nobody failed.
    it 'leaves the address open when FranceConnect+ cannot be reached on the return' do
      stub_france_connect
      visit_space
      state = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h.fetch('state')
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_timeout
      get preview_franceconnect_retour_connexion_path, params: { code: 'un-code', state: }

      expect(response).to have_http_status(:service_unavailable)
      expect(page_title).to eq(I18n.t('preview_sessions.show.unavailable.title'))
      expect(page.at_css("a[href='#{space_path}']")).to be_present
      expect(session.reload).to have_attributes(status: 'pending', identification: nil)
      expect(AuditEvent.where(event_type: 'preview_identified')).to be_empty
    end

    # An answer FranceConnect+ gave, unmotivated or not, is a refusal.
    it 'concludes the address when FranceConnect+ refuses the code' do
      stub_france_connect
      visit_space
      state = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h.fetch('state')
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_return(status: 400, body: '<html>refusé</html>')
      get preview_franceconnect_retour_connexion_path, params: { code: 'un-code', state: }

      expect(session.reload.identification).to eq('unauthenticated')
    end

    it 'leaves the address open when FranceConnect+ fails on its side' do
      stub_france_connect
      visit_space
      state = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h.fetch('state')
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_return(status: 503)
      get preview_franceconnect_retour_connexion_path, params: { code: 'un-code', state: }

      expect(response).to have_http_status(:service_unavailable)
      expect(session.reload.identification).to be_nil
    end

    # A correspondent's way back is carried through the identification only
    # where the session cookie can hold it with the rest of the departure.
    it 'departs without a way back too long for the session' do
      stub_france_connect
      visit_space(params: { returnurl: "https://portail.example/#{'a' * 4000}" })

      expect(response.headers['Location']).to start_with(FranceConnectStubs::AUTHORIZATION_ENDPOINT)
    end

    # Measured as the cookie serialises it: `<` alone weighs six bytes there.
    it 'departs without a way back that escapes beyond the session' do
      stub_france_connect
      visit_space(params: { returnurl: "https://portail.example/#{'<' * 1000}" })

      expect(response.headers['Location']).to start_with(FranceConnectStubs::AUTHORIZATION_ENDPOINT)
    end

    it 'departs with the longest way back it keeps, and a method of any length' do
      stub_france_connect
      visit_space(params: { returnurl: "https://portail.example/#{'a' * 1000}", returnmethod: 'x' * 4000 })

      expect(response.headers['Location']).to start_with(FranceConnectStubs::AUTHORIZATION_ENDPOINT)
    end

    it 'departs without a way back that is not a string' do
      stub_france_connect
      visit_space(params: { returnurl: ['https://portail.example/'] * 300, returnmethod: { a: 'x' * 4000 } })

      expect(response.headers['Location']).to start_with(FranceConnectStubs::AUTHORIZATION_ENDPOINT)
    end

    it 'leaves the address open when TLS towards FranceConnect+ fails' do
      stub_france_connect
      visit_space
      state = departure_query.fetch('state')
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_raise(Faraday::SSLError.new('certificat'))
      get preview_franceconnect_retour_connexion_path, params: { code: 'un-code', state: }

      expect(response).to have_http_status(:service_unavailable)
      expect(session.reload.identification).to be_nil
    end

    # A 5xx is an outage, even motivated in the body.
    it 'leaves the address open when FranceConnect+ fails on its side with a motivation' do
      stub_france_connect
      visit_space
      state = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h.fetch('state')
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).to_return(status: 503,
        body: { error: 'temporarily_unavailable' }.to_json, headers: { 'Content-Type' => 'application/json' })
      get preview_franceconnect_retour_connexion_path, params: { code: 'un-code', state: }

      expect(response).to have_http_status(:service_unavailable)
      expect(session.reload.identification).to be_nil
    end

    it 'shows nothing of the request when no FranceConnect+ is declared' do
      allow(Settings).to receive(:preview_france_connect_instance).and_return(nil)
      visit_space

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).not_to include('Requêteur de test')
      expect(page.css('input[type=radio], a[href$="/document"]')).to be_empty
    end

    # The answer gone, nothing is left to check: no second identification,
    # nothing journalled, and no way back offered to a browser that did not
    # choose.
    it 'sends nobody to identify on an answered address' do
      session.update!(status: 'answered', first_request: nil, return_location: 'https://portail.example/retour')
      visit_space

      expect(response).to have_http_status(:ok)
      expect(page_title).to eq(I18n.t('preview_sessions.show.recorded.title'))
      expect(response.body).not_to include('portail.example')
    end

    # One verdict per address: identifying for one request opens no other.
    it 'opens no other address to a browser identified for one' do
      other = create(:preview_session)
      identify
      get preview_session_path(segment, other.token)

      expect(response.headers['Location']).to start_with(FranceConnectStubs::AUTHORIZATION_ENDPOINT)
      get preview_session_document_path(segment, other.token)
      expect(response).to have_http_status(:not_found)
    end

    # A confirmed browser can no longer decide once someone's failure has
    # concluded the address.
    it 'takes no decision on an address a failed check concluded' do
      identify
      session.fail_identification!(PreviewSession::MISMATCHED)
      post preview_session_choice_path(segment, session.token), params: { choice: 'accepted' }

      expect(session.reload).to have_attributes(status: 'failed', decision: nil)
      expect(AuditEvent.where(event_type: 'preview_decided')).to be_empty
      get preview_session_document_path(segment, session.token)
      expect(response).to have_http_status(:not_found)
      visit_space
      expect(page_title).to eq(I18n.t('preview_sessions.show.refused.title'))
    end

    it 'answers a return no departure explains in plain text' do
      get preview_franceconnect_retour_connexion_path, params: { code: 'un-code', state: 'inconnu' }

      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq('text/plain')
    end

    it 'says identification is impossible when FranceConnect+ does not answer' do
      stub_france_connect
      stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_return(status: 503)
      visit_space

      expect(response).to have_http_status(:service_unavailable)
      expect(page_title).to eq(I18n.t('preview_sessions.show.unavailable.title'))
    end

    # CA8: the way back of the 1.2 visit survives the round trip, and a
    # browser nobody identified cannot move it.
    describe 'on the 1.2 line' do
      let!(:session) { create(:preview_session, :legacy_line) }

      it 'keeps the way back of the visit across the identification' do
        identify({ returnurl: 'https://portail.example/retour', returnmethod: 'POST' })

        expect(session.reload).to have_attributes(return_location: 'https://portail.example/retour',
          return_method: 'POST')
      end

      it 'lets no unidentified browser replace it' do
        identify({ returnurl: 'https://portail.example/retour' })
        reset!
        visit_space(params: { returnurl: 'https://ailleurs.example/' })

        expect(session.reload.return_location).to eq('https://portail.example/retour')
      end

      # A visitor who fails cannot replace the way back a confirmed visit kept,
      # and that way back is shown to neither that visitor nor any other.
      it 'lets no failing visitor replace or read the way back' do
        identify({ returnurl: 'https://portail.example/retour' })
        reset!
        identify({ returnurl: 'https://ailleurs.example/' },
          userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('birthdate' => '1965-11-26'))

        expect(session.reload.return_location).to eq('https://portail.example/retour')
        visit_space
        expect(page_title).to eq(I18n.t('preview_sessions.show.refused.title'))
        expect(response.body).not_to include('portail.example')
        get preview_session_return_path(segment, session.token)
        expect(response).to have_http_status(:not_found)
        reset!
        visit_space
        expect(page_title).to eq(I18n.t('preview_sessions.show.refused.title'))
        expect(response.body).not_to include('portail.example')
      end

      # On 1.2 the way back of the visit is offered at once after a refusal.
      it 'offers the way back of the visit to a refused user' do
        identify({ returnurl: 'https://portail.example/retour' },
          userinfo: FranceConnectStubs::REQUESTED_USERINFO.merge('birthdate' => '1965-11-26'))
        visit_space

        expect(page.at_css("a[href='https://portail.example/retour']")).to be_present
      end
    end
  end
end
