FactoryBot.define do
  factory :audit_event do
    occurred_at { Time.current }
    event_type { 'request_sent' }
    conversation_id { 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b01' }
    procedure_code { ProcedureCode::SYSTEM_CHECK }
    evidence_requester_id { '00000000000002' }

    trait :about_a_person do
      evidence_subject { { family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01' }.to_json }
      evidence_subject_key { 'königreich|ada|1990-01-01' }
    end
  end
end
