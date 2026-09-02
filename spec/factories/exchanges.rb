FactoryBot.define do
  factory :exchange do
    # The whole last group is the counter, so the value stays a UUID however
    # many the suite draws — `R-EDM-ebMS-017` and `-037` require one.
    sequence(:exchange_id) { |n| format('e0a6a5b7-6b2e-4b9c-9a63-%012d', n) }
    # Its own by default: two exchanges belong to one conversation only when a
    # spec says so, by passing the same value to both.
    sequence(:conversation_id) { |n| format('5fe50e16-d6b8-4005-b5ec-%012d', n) }
    procedure_code { ProcedureCode::SYSTEM_CHECK }
    country_code { 'FR' }
    evidence_requester_id { '00000000000002' }

    trait :sent do
      status { 'sent' }
    end

    # A request a correspondent addressed to France. `country_code` is the one
    # asking, where the default is the one asked; and the exchange carries the
    # stamp the sending gateway put on the message, which is the only clock this
    # direction has — `IncomingMessage::OpenExchange` writes it at the opening.
    trait :received do
      incoming { true }
      country_code { 'BE' }
      ebms_sent_at { Time.current }
    end

    trait :preview_required do
      status { 'preview_required' }
      preview_location { 'https://previsualisation.example.fi/consentement' }
      settled_at { Time.current }
    end

    trait :deferred do
      status { 'deferred' }
      response_available_at { 3.days.from_now }
      settled_at { Time.current }
    end

    trait :delivered do
      status { 'delivered' }
      settled_at { Time.current }
    end

    trait :failed do
      status { 'failed' }
      edm_error_code { 'EDM:ERR:0004' }
      error_description { "Le fournisseur n'a pas trouvé de justificatif correspondant." }
      settled_at { Time.current }
    end
  end
end
