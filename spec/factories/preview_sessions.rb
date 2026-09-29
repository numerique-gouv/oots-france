FactoryBot.define do
  # A preview issued for the captured request, the way `ChooseAnswer` issues one.
  factory :preview_session do
    sequence(:token) { |n| format('9b2f6c1e-3d4a-4f8b-a1c2-%012d', n) }
    location { PreviewSession.location_for(token, specification) }
    exchange_id { '9f8e8b3a-1c2d-4e5f-8a9b-0c1d2e3f4a5b' }
    conversation_id { '5fe50e16-d6b8-4005-b5ec-000000000001' }
    specification { EdmSpecification::V2_0 }
    issued_at { Time.current }
    first_request { Rails.root.join('spec/fixtures/incoming/reel/requete.xml').read }
    document { Base64.strict_encode64('%PDF-1.4 justificatif vu') }
    evidence_id { '1a2b3c4d-0000-4000-8000-000000000099' }
    evidence_issued_at { Time.current.iso8601(6) }

    trait :visited do
      first_visited_at { Time.current }
    end

    trait :legacy_line do
      specification { EdmSpecification::V1_2 }
    end
  end
end
