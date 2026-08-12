FactoryBot.define do
  factory :conversation do
    sequence(:conversation_id) { |n| "e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b#{format('%02d', n)}" }
    procedure_code { ProcedureCode::SYSTEM_CHECK }
    country_code { 'FR' }
    evidence_requester_id { '00000000000002' }
  end
end
