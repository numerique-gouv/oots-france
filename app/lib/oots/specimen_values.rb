module Oots
  # The fictional values the specimens of `SpecimenMessages` carry: realistic,
  # since the rules judge their shape and nothing else.
  module SpecimenValues
    private

    # `Substantial` and not `High`: the level travels from the beneficiary
    # token, so a specimen wearing the highest value would let a message built
    # from a constant pass unnoticed. The two optional attributes are carried
    # too, this being the document `make schematron` asks the rules about.
    def beneficiary
      @beneficiary ||= NaturalPerson.new(
        level_of_assurance: 'Substantial', eidas_identifier: 'FR/DE/123123123',
        family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22',
        place_of_birth: 'Aarhus', gender: 'Male',
      )
    end

    # The company name carries an ampersand on purpose: it makes the escaping
    # travel as far as a document Saxon must parse.
    def legal_person
      @legal_person ||= LegalPerson.new(
        # Lower case on purpose: `R-EDM-REQ-C051` and `R-EDM-RESP-C035` carry
        # the `i` flag, and this is the only document that asks the rules
        # themselves to confirm they behave as they read.
        eidas_identifier: 'fr/de/A2635542Y',
        legal_name: 'Établissements Dupont & Fils',
        identifiers: { 'VAT' => 'FR12345678901', 'LEI' => '969500HBOM1RJXTLZ57' },
      )
    end

    def evidence_type
      @evidence_type ||= EvidenceType.new(
        id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
        descriptions: { 'EN' => 'Certificate of Birth' },
        distribution_formats: [EvidenceType::PDF],
      )
    end

    # The classification of the example chapter 4.5.1 §3.4 publishes, answered.
    def code_list_classification
      EvidenceProviderClassification.new(
        id: '5ce148b9-5578-4049-aecf-af7bb55714b5',
        scheme_id: 'https://sr.oots.tech.ec.europa.eu/codelists/DE/Lau2022', type: 'codelist',
        value_expression: 'https://query.cs.oots.tech.ec.europa.eu/dsd/rest/codelists/DE/Lau2022/a591a6d4',
        descriptions: { 'EN' => 'Select the city in which you were born.' }, supported_value: '11000000',
      )
    end

    # The three types chapter 3.1.4 §4.4.3.3 has a requester support, each in
    # the value element `R-EDM-REQ-C103` or `C104` holds it to.
    def three_classifications
      [
        code_list_classification,
        EvidenceProviderClassification.new(id: '0f6f7a3e-7c55-4c2b-8f8e-6a9a3b9a1c01', type: 'boolean',
          descriptions: { 'EN' => 'Were you born abroad?' }, supported_value: 'true'),
        EvidenceProviderClassification.new(id: '0f6f7a3e-7c55-4c2b-8f8e-6a9a3b9a1c02', type: 'string',
          descriptions: { 'EN' => 'Your passport number' }, supported_value: 'AB123456'),
      ]
    end

    def requirement
      @requirement ||= Requirement.new(
        id: 'https://sr.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42',
        descriptions: { 'EN' => 'Proof of tertiary education diploma/certificate/degree' },
        details: { 'EN' => 'Proof that the person holds a diploma awarded by a tertiary education institution.' },
      )
    end

    # The data model is here on a PDF, which R-DSD-RESP-C067 says no conformant
    # directory publishes, and that is the point: R-EDM-REQ-C107 is FATAL on a
    # data model written beside an unstructured format, so this is the only
    # shape in which the rules can judge that the request leaves it out. A
    # specimen carrying none would satisfy C107 by having nothing to omit.
    def data_service
      @data_service ||= DataService.new(
        id: '41170824-15d9-4c16-984e-63b75b937b8c',
        evidence_type_classification: evidence_type.id,
        distribution_format: EvidenceType::PDF,
        distribution_language: 'EN',
        distribution_conforms_to:
          'https://sr.oots.tech.ec.europa.eu/datamodels/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40',
        descriptions: evidence_type.descriptions,
        details: { 'EN' => 'Birth certificate issued by the civil registration office.' },
      )
    end

    # The structured distribution a portal names by `format`, published without
    # a data model, as the acceptance directory publishes several: chapter
    # 4.5.1 §3.5 lets it travel without `sdg:ConformsTo`, which R-EDM-REQ-C070
    # and C071 only warn of.
    def structured_data_service
      DataService.new(
        **data_service.attributes.symbolize_keys, descriptions: data_service.descriptions,
        details: data_service.details,
        distributions: [Distribution.new(format: EvidenceType::PDF, language: 'EN'),
                        Distribution.new(format: 'application/xml')]
      ).requesting('application/xml')
    end
  end
end
