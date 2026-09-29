require 'rails_helper'

# The return address of chapter 4.9 §5, as a user's browser follows it.
RSpec.describe 'GET /retour/:token' do
  let(:exchange) { create(:exchange, :preview_confirmed, resume_location: 'https://demarche.example.fr/reprise?etape=3') }

  # CA6 of OOTS-67: redirected, with the two identifiers the procedure resumes
  # by, and nothing rendered.
  it 'sends the user back to the procedure, naming the exchange' do
    get "/retour/#{exchange.return_token}"

    expect(response).to have_http_status(:see_other)
    expect(response.location).to eq('https://demarche.example.fr/reprise?etape=3' \
                                    "&echange=#{exchange.exchange_id}&conversation=#{exchange.conversation_id}")
    expect(response.body).to be_empty
  end

  it 'does so every time it is followed' do
    2.times { get "/retour/#{exchange.return_token}" }

    expect(response).to have_http_status(:see_other)
  end

  # RG16 of OOTS-67: this deployment's own addition to the log.
  it 'journals the visit on the exchange' do
    get "/retour/#{exchange.return_token}"

    expect(AuditEvent.last).to have_attributes(event_type: 'return_to_procedure', exchange_id: exchange.exchange_id,
      preview_location: "http://www.example.com/retour/#{exchange.return_token}")
  end

  # CA7 of OOTS-67.
  it 'knows no address it never issued' do
    get '/retour/3f2c1a4e-5b6d-4e7f-8a9b-0c1d2e3f4a5b'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq(I18n.t('returns.show.unknown'))
  end

  # Chapter 4.9 §5: « shall not be accessible before the second request is
  # issued ».
  it 'is not open before the second request has gone' do
    pending_one = create(:exchange, :preview_confirmed, status: 'pending')

    get "/retour/#{pending_one.return_token}"

    expect(response).to have_http_status(:not_found)
  end

  it 'is gone past T3' do
    expired = create(:exchange, :preview_confirmed, preview_confirmed_at: Settings.requester_decision_timeout.ago - 1.minute)

    get "/retour/#{expired.return_token}"

    expect(response).to have_http_status(:gone)
    expect(response.body).to eq(I18n.t('returns.show.expired'))
  end
end
