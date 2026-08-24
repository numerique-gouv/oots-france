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

    trait :preview_required do
      status { 'preview_required' }
      preview_location { 'https://previsualisation.example.fi/consentement' }
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
