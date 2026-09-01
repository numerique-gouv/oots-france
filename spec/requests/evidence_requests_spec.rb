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
  let(:exchange) { create(:exchange) }
  let(:fetch_result) { Interactor::Context.build(exchange:) }

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
    expect(response.parsed_body).to include(
      'echange' => exchange.exchange_id, 'conversation' => exchange.conversation_id, 'statut' => 'pending',
    )
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
        country_code: parameters[:codePays],
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
    # way, and the keys have to stay in step with `FAILURE_STATUSES`.
    it 'reports a directory that cannot be reached as 502 too' do
      allow(EvidenceRequest::Fetch).to receive(:call)
        .and_return(failure(:common_services_refused, 'Annuaire injoignable.'))

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:bad_gateway)
    end

    # A directory publishing an entry the rules refuse is no more the caller's
    # doing than one that is down — the difference between the two is what the
    # journal keeps, not what the status says.
    it 'reports an entry a directory published against the rules as 502 too' do
      allow(EvidenceRequest::Fetch).to receive(:call)
        .and_return(failure(:invalid_directory_entry, "L'exigence annoncée par l'annuaire : …"))

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:bad_gateway)
    end

    # A directory that returned an access point contradicting the `specification`
    # filter the query carried is the same kind of upstream fault, and the keys
    # have to stay in step with `FAILURE_STATUSES`.
    it 'reports an access point that does not speak our version as 502 too' do
      allow(EvidenceRequest::Fetch).to receive(:call)
        .and_return(failure(:unsupported_specification,
          "Le point d'accès AP_DE_01 annonce oots-edm:v1.2, et non oots-edm:v2.0 : la requête n'est pas émise."))

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['erreur']).to include('oots-edm:v1.2', 'oots-edm:v2.0')
    end

    # Neither 422 nor 502: a message this deployment cannot build is upstream of
    # nobody, and a 422 would send the caller correcting a request that was
    # never in question. Structured all the same, so the failure reaches them as
    # an answer they can read rather than as an unhandled exception.
    it 'reports a configuration it cannot build a message from as a structured 500' do
      allow(EvidenceRequest::Fetch).to receive(:call)
        .and_return(failure(:invalid_configuration, 'La configuration de cette installation ne permet pas de construire la requête : Le requêteur : …'))

      get '/requete/pieceJustificative', params: parameters

      expect(response).to have_http_status(:internal_server_error)
      expect(response.parsed_body).to include('erreur' => /cette installation/)
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
        country_code: parameters[:codePays],
        detail: 'Jeton invalide',
      )
    end
  end

  # Chapter 4.4 lets the Procedure Portal assign the conversation identifier, so
  # that two requests can be said to be one user's.
  describe 'the conversation the caller may name' do
    it 'passes on the one it was given' do
      get '/requete/pieceJustificative',
        params: parameters.merge(idConversation: '5fe50e16-d6b8-4005-b5ec-0ab097f34448')

      expect(EvidenceRequest::Fetch).to have_received(:call)
        .with(hash_including(conversation_id: '5fe50e16-d6b8-4005-b5ec-0ab097f34448'))
    end

    it 'leaves it to be minted when the caller names none' do
      get '/requete/pieceJustificative', params: parameters

      expect(EvidenceRequest::Fetch).to have_received(:call).with(hash_including(conversation_id: nil))
    end

    # `R-EDM-ebMS-017` is FATAL, and the value would travel in the header of
    # every message of this exchange. Refused before anything is decrypted or
    # any directory called.
    it 'refuses one that is not a UUID, before calling anything' do
      get '/requete/pieceJustificative', params: parameters.merge(idConversation: 'pas-un-uuid')

      expect(response).to have_http_status(:unprocessable_content)
      expect(EvidenceRequest::Fetch).not_to have_received(:call)
    end

    it 'journals that refusal, which no gateway log would hold' do
      get '/requete/pieceJustificative', params: parameters.merge(idConversation: 'pas-un-uuid')

      expect(AuditEvent.sole).to have_attributes(event_type: 'request_refused',
        detail: I18n.t('evidence_requests.conversation_invalid'))
    end
  end

  # The exchange settles on another connection entirely, so this is where a
  # caller holding the identifier learns how it ended.
  describe 'reading the state back' do
    it 'reports the EDM code a correspondent refused with' do
      exchange.failed!(code: 'EDM:ERR:0004', description: 'Object not found')

      get "/requete/#{exchange.exchange_id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('statut' => 'failed', 'codeErreur' => 'EDM:ERR:0004')
    end

    # Chapter 4.5.2: « the Online Procedure Portal may use this information to
    # inform the user to pause the procedure and to return at a later point ».
    # Without the date the portal learns that it gets nothing, never when to
    # come back and ask again.
    it 'reports the date a correspondent announced the evidence for' do
      exchange.deferred!(Time.zone.parse('2026-09-01T08:00:00Z'))

      get "/requete/#{exchange.exchange_id}"

      expect(response.parsed_body).to include(
        'statut' => 'deferred', 'dateDisponibilite' => '2026-09-01T10:00:00+02:00',
      )
    end

    it 'says nothing of a date on an exchange nobody deferred' do
      exchange.delivered!

      get "/requete/#{exchange.exchange_id}"

      expect(response.parsed_body).not_to have_key('dateDisponibilite')
    end

    it 'answers 404 for an exchange it never opened' do
      get '/requete/un-echange-inconnu'

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
