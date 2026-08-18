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

  factory :reference_framework do
    id { '92c27c13-5c49-439b-a334-683d736a0cb7' }
    procedure_code { '00' }
    country { 'FR' }
    descriptions { { 'EN' => 'Test - FR - MS Procedure' } }

    initialize_with { new(**attributes) }
  end

  factory :requirement do
    id { 'https://sr.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000' }
    descriptions { { 'EN' => '(TEST) Test Requirement' } }
    reference_frameworks { [build(:reference_framework)] }

    initialize_with { new(**attributes) }
  end

  factory :evidence_type_list do
    id { '91ecb80f-c74a-48bd-ad43-2a6f1bdb5a7d' }
    country { 'FR' }
    descriptions { { 'EN' => 'FR - Test Evidence Type List' } }
    evidence_types { [build(:evidence_type)] }

    initialize_with { new(**attributes) }
  end

  factory :data_service do
    id { '41170824-15d9-4c16-984e-63b75b937b8c' }
    evidence_type_classification { build(:evidence_type).id }
    distribution_format { EvidenceType::PDF }
    level_of_assurance { 'Substantial' }
    descriptions { { 'EN' => 'Dummy PDF - FI' } }
    providers { [build(:evidence_provider)] }

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
