FactoryBot.define do
  factory :audit_event do
    occurred_at { Time.current }
    event_type { 'request_sent' }
    exchange_id { 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b01' }
    conversation_id { '5fe50e16-d6b8-4005-b5ec-0ab097f34001' }
    procedure_code { ProcedureCode::SYSTEM_CHECK }
    evidence_requester_id { '00000000000002' }

    # Composed as `AuditTrail` composes it, and never by hand: a deterministic
    # column is only searchable by a value built exactly as it was stored, so a
    # factory spelling the key out could prove a search that no exchange answers.
    trait :about_sophie do
      transient { person { { family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25' } } }

      evidence_subject { person.to_json }
      evidence_subject_key { AuditEvent.subject_key(**person) }
    end

    # The first MIME part as it circulated, which chapter 4.8 has the log keep
    # whole in both directions.
    trait :with_regrep_body do
      regrep_mime_type { 'application/x-ebrs+xml' }
      regrep_body { '<query:QueryRequest id="urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700"/>' }
    end

    trait :about_a_person do
      transient { person { { family_name: 'Königreich', given_name: 'Ada', date_of_birth: '1990-01-01' } } }

      evidence_subject { person.to_json }
      evidence_subject_key { AuditEvent.subject_key(**person) }
    end
  end
end
