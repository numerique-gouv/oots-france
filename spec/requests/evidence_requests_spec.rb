require 'rails_helper'

RSpec.describe 'GET /requete/pieceJustificative' do
  let(:parameters) do
    {
      codeDemarche: ProcedureCode::SYSTEM_CHECK,
      codePays: 'FR',
      idRequeteur: '00000000000002',
      beneficiaire: 'un-jeton-chiffré',
    }
  end
  let(:conversation) { create(:conversation) }
  let(:fetch_result) { Interactor::Context.build(conversation:) }

  before do
    allow(Settings).to receive_messages(
      evidence_request_enabled?: true,
      evidence_requesters_data: { '00000000000002' => { 'nom' => 'Requêteur', 'url' => 'http://localhost:4000' } },
    )
    allow(EvidenceRequest::Fetch).to receive(:call).and_return(fetch_result)
  end

  # The answer is not something a request can sit and wait for, so the caller
  # is told the exchange was accepted and under which identifier.
  it 'accepts at once, without waiting for the gateway' do
    get '/requete/pieceJustificative', params: parameters

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to include('conversation' => conversation.conversation_id, 'statut' => 'pending')
  end

  describe 'the feature flag' do
    # Unchanged: the system is not accredited, and the querying stays shut in
    # production until it is.
    it 'answers 501 when the querying is not enabled' do
      allow(Settings).to receive(:evidence_request_enabled?).and_return(false)

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:not_implemented)
    end
  end

  describe 'what it refuses' do
    it 'refuses a request with no beneficiary, before calling anything' do
      get '/requete/pieceJustificative', params: parameters.except(:beneficiaire)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['erreur']).to eq('Le bénéficiaire doit être renseigné')
    end

    # Refused by a `before_action` rather than by a failed interactor, which is
    # exactly how a refusal escapes being journalled if nobody looks.
    it 'journals a refusal pronounced before any interactor runs' do
      get '/requete/pieceJustificative', params: parameters.except(:beneficiaire)

      expect(AuditEvent.last).to have_attributes(
        event_type: 'request_refused',
        detail: 'Le bénéficiaire doit être renseigné',
      )
    end

    # The resolution itself is `ResolveRequester`'s, and has its own spec: what
    # is checked here is that its structured failure reaches the caller.
    it 'refuses a requester the directory does not know' do
      allow(EvidenceRequest::Fetch).to receive(:call)
        .and_return(failure(:unknown_requester, 'Le requêteur avec comme identifiant « 00000000000009 » est inexistant.'))

      get '/requete/pieceJustificative', params: parameters.merge(idRequeteur: '00000000000009')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['erreur']).to include('00000000000009')
    end

    it 'reports a rejected token as the caller fault' do
      allow(EvidenceRequest::Fetch).to receive(:call).and_return(failure(:invalid_token, 'Jeton invalide'))

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:unprocessable_content)
    end

    # The gateway refusing is a failure upstream of the caller: blaming them
    # with a 422 would send them looking in the wrong place.
    it 'reports a gateway refusal as 502, not as the caller fault' do
      allow(EvidenceRequest::Fetch).to receive(:call).and_return(failure(:gateway_refused, 'connexion refusée'))

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:bad_gateway)
    end

    # A central directory that is down is upstream of the caller in the same
    # way, and the two keys have to stay in step with `UPSTREAM_FAILURES`.
    it 'reports a directory that cannot be reached as 502 too' do
      allow(EvidenceRequest::Fetch).to receive(:call)
        .and_return(failure(:common_services_refused, 'Annuaire injoignable.'))

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:bad_gateway)
    end

    # A refusal here produces no ebMS message at all, so the gateway holds no
    # trace of it — and article 17 asks for the errors as much as the exchanges.
    it 'journals the refusal, which no gateway log would hold' do
      allow(EvidenceRequest::Fetch).to receive(:call).and_return(failure(:invalid_token, 'Jeton invalide'))

      get '/requete/pieceJustificative', params: parameters

      expect(AuditEvent.last).to have_attributes(
        event_type: 'request_refused',
        evidence_requester_id: parameters[:idRequeteur],
        procedure_code: parameters[:codeDemarche],
        detail: 'Jeton invalide',
      )
    end
  end

  # The exchange settles on another connection entirely, so this is where a
  # caller holding the identifier learns how it ended.
  describe 'reading the state back' do
    it 'reports the EDM code a correspondent refused with' do
      conversation.failed!(code: 'EDM:ERR:0004', description: 'Object not found')

      get "/requete/#{conversation.conversation_id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('statut' => 'failed', 'codeErreur' => 'EDM:ERR:0004')
    end

    it 'answers 404 for an exchange it never opened' do
      get '/requete/une-conversation-inconnue'

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['erreur']).to be_present
    end
  end

  # A real context rather than a double: `Interactor::Context` answers through
  # `method_missing`, so a verifying double cannot know what it implements and
  # refuses every message.
  def failure(key, message)
    Interactor::Context.build.tap do |context|
      context.fail!(error: { key:, errors: [message] })
    rescue Interactor::Failure
      nil
    end
  end
end
