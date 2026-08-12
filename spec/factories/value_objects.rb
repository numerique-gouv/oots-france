FactoryBot.define do
  factory :ebms_identity do
    id { '00000000000002' }
    type_id { IdentifierScheme::FRENCH }

    initialize_with { new(**attributes) }
  end

  factory :address do
    country { 'FR' }

    initialize_with { new(**attributes) }
  end

  factory :access_point do
    id { 'blue_gw' }
    type_id { 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots' }

    initialize_with { new(**attributes) }
  end

  factory :natural_person do
    family_name { 'Dupont' }
    given_name { 'Sophie' }
    date_of_birth { '1965-11-25' }
    eidas_identifier { nil }

    initialize_with { new(**attributes) }
  end

  factory :evidence_type do
    id { 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000' }
    distribution_format { EvidenceType::PDF }
    descriptions { { 'EN' => 'Test evidence' } }

    initialize_with { new(**attributes) }
  end

  factory :evidence_requester do
    id { '00000000000002' }
    name { "Ministère de l'enseignement supérieur" }
    url { 'http://localhost:4000' }
    type_id { IdentifierScheme::FRENCH }
    language { 'FR' }

    initialize_with { new(**attributes) }
  end

  factory :evidence_provider do
    identifier { build(:ebms_identity, id: '00000000000003') }
    access_point { build(:access_point) }
    descriptions { { 'FR' => 'Fournisseur de test' } }

    initialize_with { new(**attributes) }
  end
end
