require 'rails_helper'

RSpec.describe 'The preview space' do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  let!(:session) { create(:preview_session) }
  let(:page) { response.parsed_body }

  def visit_space(token = session.token, params: {}) = get(preview_session_path(token), params:)

  describe 'a first visit within T2' do
    before { visit_space }

    # CA7: no operator session, who asks and for what, the document offered.
    it 'shows who asks for which document, and offers it' do
      expect(response).to have_http_status(:ok)
      expect(page.text).to include('Requêteur de test')
      link = page.at_css("a[href='#{preview_session_document_path(session.token)}']")

      expect(link).to have_attributes(attributes: include('target', 'rel', 'title'))
      expect([link['target'], link['rel'], link['download']]).to eq(['_blank', 'noopener', nil])
      expect(link['title']).to end_with('nouvelle fenêtre')
    end

    # CA7 and CA8: two radio buttons and nothing to type.
    it 'asks for a decision and nothing else' do
      expect(page.css('input[type=radio]').pluck('value')).to eq(PreviewSession::DECISIONS)
      expect(page.css('input:not([type=radio]):not([type=hidden]):not([type=submit]), textarea, select')).to be_empty
    end

    # CA26: chapter 4.8 §3.2, the URL visited.
    it 'journals the visit with the address visited' do
      expect(AuditEvent.sole).to have_attributes(event_type: 'preview_visited', exchange_id: session.exchange_id,
        preview_location: "http://www.example.com#{preview_session_path(session.token)}")
    end
  end

  # CA8: the document offered is the one the answer will carry.
  it 'serves the very document it keeps' do
    get preview_session_document_path(session.token)

    expect(response.media_type).to eq('application/pdf')
    expect(response.headers['Content-Disposition']).to start_with('inline')
    expect(response.body).to eq(session.document_bytes)
  end

  # CA9: once the choice is made, the document is no longer served.
  it 'no longer serves the document once the choice is made' do
    session.decide!(accepted: true)
    get preview_session_document_path(session.token)

    expect(response).to have_http_status(:not_found)
  end

  # CA10: an address France did not issue says nothing of any request.
  it 'says an unknown link is no longer valid' do
    visit_space('inconnu')

    expect(response).to have_http_status(:not_found)
    expect(page.at_css('h1').text).to eq(I18n.t('preview_sessions.show.invalid.title'))
    expect(page.text).not_to include('Requêteur de test')
  end

  it 'says the delay ran out past T2' do
    travel(17.minutes) { visit_space }

    expect(page.at_css('h1').text).to eq(I18n.t('preview_sessions.show.expired.title'))
  end

  describe 'the choice' do
    def choose(choice) = post(preview_session_choice_path(session.token), params: { choice: })

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
    it 'waits for the second request before offering the way back' do
      choose('accepted')
      visit_space

      expect(page.text).to include(I18n.t('preview_sessions.return.awaiting'))
      session.update!(return_location: 'https://portail.example/retour')
      get preview_session_return_path(session.token)

      expect(response.parsed_body.at_css('a')['href']).to eq('https://portail.example/retour')
    end
  end

  describe 'the 1.2 line' do
    let!(:session) { create(:preview_session, :legacy_line) }

    # CA17: the way back comes with the visit, offered as soon as the choice is made.
    it 'offers the way back the visit brought' do
      visit_space(params: { returnurl: 'https://portail.example/retour', returnmethod: 'GET' })
      post preview_session_choice_path(session.token), params: { choice: 'accepted' }
      follow_redirect!

      expect(response.parsed_body.at_css('a.fr-btn')['href']).to eq('https://portail.example/retour')
    end

    # Chapter 4.9 v1.2.3 §5: another method than GET is followed by a form
    # with an empty body.
    it 'offers the way back as a form when the visit asked for POST' do
      visit_space(params: { returnurl: 'https://portail.example/retour', returnmethod: 'post' })
      post preview_session_choice_path(session.token), params: { choice: 'refused' }
      follow_redirect!

      form = response.parsed_body.at_css("form[action='https://portail.example/retour']")
      expect(form['method']).to eq('post')
      expect(form.css('input')).to be_empty
      expect(AuditEvent.find_by(event_type: 'preview_decided').detail).to eq('refused')
    end

    # Once the choice is made, a later visit no longer moves the way back the
    # page offers.
    it 'keeps the way back once the choice is made' do
      visit_space(params: { returnurl: 'https://portail.example/retour' })
      post preview_session_choice_path(session.token), params: { choice: 'accepted' }
      visit_space(params: { returnurl: 'https://ailleurs.example/' })

      expect(session.reload.return_location).to eq('https://portail.example/retour')
    end

    it 'falls back on GET for a method chapter 4.9 does not name' do
      visit_space(params: { returnurl: 'https://portail.example/retour', returnmethod: 'DELETE' })

      expect(session.reload.return_method).to eq('GET')
    end

    # CA18: no safe way back, a warning, and the decision all the same.
    it 'warns a user who came without a safe way back' do
      stub_const('ENV', ENV.to_h.merge('URL_OOTS_FRANCE' => 'https://oots.example'))
      visit_space(params: { returnurl: 'http://portail.example/retour' })

      expect(page.css('.fr-alert--warning')).to be_present
      expect(page.css('input[type=radio]').size).to eq(2)
    end
  end
end
