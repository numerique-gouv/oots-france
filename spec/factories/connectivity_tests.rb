FactoryBot.define do
  # A test asked towards the Greek access point, still waiting for the gateway.
  factory :connectivity_test do
    sequence(:party_name) { |n| format('AP_EL_%02d', n) }
    party_identifier { party_name }
    party_identifier_type { 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL' }
    requested_at { 2.minutes.ago }

    trait :submitted do
      sequence(:message_id) { |n| format('3f2b1c4d-5e6f-4a7b-8c9d-%012d@domibus.eu', n) }
    end

    trait :acknowledged do
      submitted
      outcome { ConnectivityTest::ACKNOWLEDGED }
      verdict_read_at { Time.current }
    end
  end
end
