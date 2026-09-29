require 'rails_helper'

RSpec.describe 'POST /requete/:exchange_id/previsualisation' do
  let(:exchange) { create(:exchange, :preview_required, :with_request_basis) }
  let(:parameters) { { beneficiaire: 'un-jeton-chiffré', adresseRetour: 'https://demarche.example.fr/reprise' } }
  let(:confirmed) do
    # The exchange as the chain leaves it, the second request gone.
    reopened = build(:exchange, :preview_confirmed, exchange_id: exchange.exchange_id,
      conversation_id: exchange.conversation_id)

    Interactor::Context.build(exchange: reopened, preview_link: PreviewLink.new(
      location: exchange.preview_location, return_location: 'https://oots.example.fr/retour/x',
      specification: exchange.specification,
    ))
  end

  before do
    allow(Settings).to receive(:evidence_request_enabled?).and_return(true)
    allow(EvidenceRequest::ConfirmPreview).to receive(:call).and_return(confirmed)
  end

  def confirm(params = parameters, awaiting: exchange) = post("/requete/#{awaiting.exchange_id}/previsualisation", params:)

  # CA2 of OOTS-67.
  it 'accepts, and answers with the link to present' do
    confirm

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include(
      'echange' => exchange.exchange_id, 'statut' => 'sent',
      'adressePrevisualisation' => exchange.preview_location, 'methodePrevisualisation' => 'GET',
    )
    expect(response.parsed_body).not_to have_key('corpsPrevisualisation')
  end

  it 'hands the chain the token and the address it was given' do
    confirm

    expect(EvidenceRequest::ConfirmPreview).to have_received(:call).with(hash_including(
      exchange:, encrypted_beneficiary: 'un-jeton-chiffré', resume_location: 'https://demarche.example.fr/reprise',
      requester_id: exchange.evidence_requester_id,
    ))
  end

  # CA3 of OOTS-67.
  describe 'what it refuses before emitting anything' do
    it 'refuses a confirmation without its token' do
      confirm(parameters.except(:beneficiaire))

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['erreur']).to be_present
      expect(EvidenceRequest::ConfirmPreview).not_to have_received(:call)
    end

    it 'refuses an address to bring the user back to that is not one' do
      confirm(parameters.merge(adresseRetour: 'retour'))

      expect(response).to have_http_status(:unprocessable_content)
      expect(EvidenceRequest::ConfirmPreview).not_to have_received(:call)
    end

    it 'refuses a token the chain could not read' do
      allow(EvidenceRequest::ConfirmPreview).to receive(:call).and_return(failure(:invalid_token, 'illisible'))

      confirm

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses an exchange that awaits no confirmation' do
      confirm(awaiting: create(:exchange, :delivered))

      expect(response).to have_http_status(:conflict)
      expect(EvidenceRequest::ConfirmPreview).not_to have_received(:call)
    end

    # CA15: the chain decides a race under its lock, and says so the same way.
    it 'reports a confirmation another one overtook as a conflict too' do
      allow(EvidenceRequest::ConfirmPreview).to receive(:call).and_return(failure(:preview_not_awaited, 'déjà'))

      confirm

      expect(response).to have_http_status(:conflict)
    end

    it 'answers 404 for an exchange France did not ask for' do
      confirm(awaiting: create(:exchange, :received, :preview_required))

      expect(response).to have_http_status(:not_found)
    end

    it 'journals the refusal, which no gateway log would hold' do
      confirm(parameters.except(:beneficiaire))

      expect(AuditEvent.last).to have_attributes(event_type: 'request_refused', exchange_id: exchange.exchange_id)
    end
  end

  # CA13 of OOTS-67: on 1.2, a POST sends the return address in its body.
  it 'hands over the body a POST sends, on 1.2' do
    legacy = create(:exchange, :preview_required, :legacy_line, preview_method: 'POST')
    link = PreviewLink.new(location: legacy.preview_location, return_location: 'https://oots.example.fr/retour/x',
      specification: legacy.specification, preview_method: 'POST')
    allow(EvidenceRequest::ConfirmPreview).to receive(:call)
      .and_return(Interactor::Context.build(exchange: legacy, preview_link: link))

    confirm(awaiting: legacy)

    expect(response.parsed_body).to include('methodePrevisualisation' => 'POST',
      'corpsPrevisualisation' => 'returnurl=https%3A%2F%2Foots.example.fr%2Fretour%2Fx&returnmethod=GET')
  end

  def failure(key, message)
    Interactor::Context.build.tap do |context|
      context.fail!(error: { key:, errors: [message] })
    rescue Interactor::Failure
      nil
    end
  end
end
