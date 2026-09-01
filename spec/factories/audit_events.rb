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

    # The other subject chapter 4.5.1 allows: identifiers that are a structure
    # rather than a field, and a name carrying an ampersand the JSON encoder
    # writes as `\u0026`. Composed by `AuditEvent.subject` and not by hand, key
    # included, so that a spec cannot prove a search no exchange answers.
    trait :about_an_organisation do
      transient do
        organisation { build(:legal_person, identifiers: { 'VAT' => 'FR12345678901' }) }
        written { AuditEvent.subject(organisation) }
      end

      evidence_subject { written[:evidence_subject] }
      evidence_subject_key { written[:evidence_subject_key] }
    end

    # A subject a correspondent answered short of a field, which chapter 4.6
    # leaves nobody the duty to refuse: `EvidenceResponseParser#evidence_subject`
    # records it as it came, and it composes neither form of key. The one line
    # of the journal that carries no key at all.
    trait :about_an_incomplete_person do
      transient do
        person { { eidas_identifier: 'FR/DE/123123123', family_name: 'Königreich', given_name: 'Ada' } }
      end

      evidence_subject { person.to_json }
      evidence_subject_key { AuditEvent.canonical_key(person) }
    end
  end
end
