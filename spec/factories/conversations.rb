FactoryBot.define do
  factory :conversation do
    sequence(:conversation_id) { |n| "e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b#{format('%02d', n)}" }
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
