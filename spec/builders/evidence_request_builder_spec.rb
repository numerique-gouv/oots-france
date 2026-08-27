require 'rails_helper'

RSpec.describe EvidenceRequestBuilder do
  subject(:request) { described_class.new(**attributes).render }

  let(:attributes) do
    {
      requester: EvidenceRequester.french(id: '00000000000002', name: "Ministère de l'enseignement supérieur"),
      provider: EvidenceProvider.new(
        identifier: EbmsIdentity.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
        descriptions: { 'EN' => 'Civil Registration Office Berlin I' },
      ),
      beneficiary: NaturalPerson.new(
        eidas_identifier: 'FR/DE/123123123', family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22',
      ),
      requirement: Requirement.new(
        id: 'https://sr.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42',
        descriptions: { 'EN' => 'Proof of tertiary education diploma/certificate/degree' },
        details: { 'EN' => 'Proof that the person holds a diploma awarded by a tertiary education institution.' },
      ),
      data_service: DataService.new(
        id: '41170824-15d9-4c16-984e-63b75b937b8c',
        evidence_type_classification:
          'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
        distribution_format: 'application/pdf',
        distribution_language: 'EN',
        descriptions: { 'EN' => 'Certificate of Birth' },
        details: { 'EN' => 'Birth certificate issued by the civil registration office.' },
      ),
      procedure_code: ProcedureCode::DIPLOMA_RECOGNITION,
      clock: instance_double(Clock, now: '2026-08-06T10:00:00.000Z'),
      uuid: instance_double(UuidGenerator, next: '1a2b3c4d-0000-4000-8000-000000000000'),
    }
  end

  it 'renders the request as the reference message has it' do
    expect(request).to be_equivalent_xml_to(reference_message('requete'))
  end

  it 'is well-formed XML' do
    expect(Nokogiri::XML(request).errors).to be_empty
  end

  # OOTS-France is not the requester: it relays on its behalf, and the TDD have
  # it declare itself as a second agent so the exchange records who carried it.
  it 'declares OOTS-France alongside the requester, as intermediary platform' do
    classifications = Nokogiri::XML(request)
      .xpath('//sdg:Agent/sdg:Classification', 'sdg' => 'http://data.europa.eu/p4s')
      .map(&:text)

    expect(classifications).to eq(%w[ER IP])
  end

  # An address is required on the requester (R-EDM-REQ-C073); the provider of a
  # request is merely designated, and carries neither address nor
  # classification.
  it 'gives an address to the requester and none to the provider' do
    document = Nokogiri::XML(request)
    namespaces = { 'sdg' => 'http://data.europa.eu/p4s', 'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0' }
    provider = document.at_xpath('//rim:Slot[@name="EvidenceProvider"]', namespaces)

    expect(document.xpath('//sdg:Address', namespaces).size).to eq(1)
    expect(provider.xpath('.//sdg:Address', namespaces)).to be_empty
  end

  describe 'the preview flag' do
    it 'is false by default' do
      expect(request).to include('<rim:Value>false</rim:Value>')
    end

    it 'is true when the caller asked for a preview' do
      rendered = described_class.new(**attributes, preview_possible: true).render
      slot = Nokogiri::XML(rendered).at_xpath(
        '//rim:Slot[@name="PossibilityForPreview"]//rim:Value',
        'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0',
      )

      expect(slot.text).to eq('true')
    end
  end

  # R-EDM-REQ-S038 bounds what a requirement may carry, and R-EDM-REQ-C010 and
  # C094 make the `lang` attribute mandatory on each of the two.
  it 'declares the requirement the Evidence Broker named, in every language it published' do
    multilingual = Requirement.new(
      id: 'https://sr.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42',
      descriptions: { 'EN' => 'Test requirement', 'FI' => 'Testivaatimus' },
      details: { 'EN' => 'What it proves' },
    )
    declared = Nokogiri::XML(described_class.new(**attributes, requirement: multilingual).render)
      .at_xpath('//sdg:Requirement', 'sdg' => 'http://data.europa.eu/p4s')

    expect(declared.element_children.map(&:name)).to eq(%w[Identifier Name Name Description])
    expect(declared.element_children.drop(1).pluck('lang')).to eq(%w[EN FI EN])
  end

  # Same loop as the requirement above, on the other slot the directories feed,
  # and bounded by R-EDM-REQ-S045 — nothing but those five elements.
  it 'names the evidence type in every language the directory published' do
    multilingual = DataService.new(
      id: '41170824-15d9-4c16-984e-63b75b937b8c',
      evidence_type_classification:
        'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
      distribution_format: 'application/pdf',
      descriptions: { 'EN' => 'Certificate of Birth', 'DE' => 'Geburtsurkunde' },
      details: { 'EN' => 'What it proves' },
    )
    declared = Nokogiri::XML(described_class.new(**attributes, data_service: multilingual).render)
      .at_xpath('//sdg:DataServiceEvidenceType', 'sdg' => 'http://data.europa.eu/p4s')

    expect(declared.element_children.map(&:name))
      .to eq(%w[Identifier EvidenceTypeClassification Title Title Description DistributedAs])
    expect(declared.xpath('./sdg:Title | ./sdg:Description', 'sdg' => 'http://data.europa.eu/p4s').pluck('lang'))
      .to eq(%w[EN DE EN])
  end

  # Chapter 4.5.1 makes the language « as selected by the requester from the
  # language distributions defined in the DSD » — so there is nothing to write
  # where the directory published none, and the answer then comes in any
  # available language.
  describe 'the language of the evidence asked for' do
    subject(:distribution) do
      Nokogiri::XML(request).at_xpath('//sdg:DistributedAs', 'sdg' => 'http://data.europa.eu/p4s')
    end

    it 'is the one the Data Service Directory published' do
      expect(distribution.element_children.map(&:name)).to eq(%w[Format Language])
      expect(distribution.at_xpath('./sdg:Language', 'sdg' => 'http://data.europa.eu/p4s').text).to eq('EN')
    end

    context 'when the directory published none' do
      subject(:request) do
        silent = DataService.new(
          id: '41170824-15d9-4c16-984e-63b75b937b8c',
          evidence_type_classification:
            'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
          distribution_format: 'application/pdf',
        )

        described_class.new(**attributes, data_service: silent).render
      end

      it 'is left out' do
        expect(distribution.element_children.map(&:name)).to eq(%w[Format])
      end
    end
  end

  # R-EDM-REQ-S016: a Query states one subject or the other, never both. The
  # reference message above covers the natural person; this covers the swap.
  describe 'a request about a legal person' do
    subject(:query) do
      Nokogiri::XML(described_class.new(**attributes, beneficiary: LegalPerson.new(
        legal_name: 'Établissements Dupont & Fils', eidas_identifier: 'FR/DE/A2635542Y',
        identifiers: { 'VAT' => 'FR12345678901' },
      )).render).at_xpath('//query:Query', namespaces)
    end

    let(:namespaces) do
      {
        'query' => 'urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0',
        'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0',
        'sdg' => 'http://data.europa.eu/p4s',
        'xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
      }
    end

    # R-EDM-REQ-S034 types the slot value, and R-EDM-REQ-S047 has it carry an
    # `sdg:LegalPerson` of the p4s namespace.
    it 'carries the legal person and no natural person' do
      slot = query.at_xpath('./rim:Slot[@name="LegalPerson"]', namespaces)

      expect(slot.at_xpath('./rim:SlotValue[@xsi:type="rim:AnyValueType"]', namespaces)).to be_present
      expect(slot.at_xpath('.//sdg:LegalPerson/sdg:LegalName', namespaces).text)
        .to eq('Établissements Dupont & Fils')
      expect(query.at_xpath('./rim:Slot[@name="NaturalPerson"]', namespaces)).to be_nil
    end
  end

  # A subject of a type the query has no slot for would otherwise go out as a
  # request stating nothing about whom it is for. `ConfigurationError` and not
  # the bare `KeyError`: no interactor rescues the latter.
  it 'refuses to build a request about a subject it has no slot for' do
    expect { described_class.new(**attributes, beneficiary: 'Dupont').render }
      .to raise_error(ConfigurationError, /String/)
  end

  # Chapter 4.5.1 has the request carry back the data model the DSD published,
  # so that a correspondent asked for a structured format knows which model to
  # produce it against — R-EDM-REQ-C070 and C071 make its absence a warning
  # there, and R-EDM-REQ-C107 makes its presence fatal elsewhere.
  describe 'the data model asked for' do
    subject(:distribution) do
      Nokogiri::XML(described_class.new(**attributes, data_service: published).render)
        .at_xpath('//sdg:DistributedAs', 'sdg' => 'http://data.europa.eu/p4s')
    end

    let(:model) { 'https://sr.oots.tech.ec.europa.eu/datamodels/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40' }
    let(:published) { build(:data_service, distribution_conforms_to: model, distribution_format: format) }

    context 'when the requested format is structured' do
      let(:format) { 'application/xml' }

      it 'is written after the language, where the schema puts it' do
        expect(distribution.element_children.map(&:name)).to eq(%w[Format Language ConformsTo])
        expect(distribution.at_xpath('./sdg:ConformsTo', 'sdg' => 'http://data.europa.eu/p4s').text).to eq(model)
      end
    end

    # R-EDM-REQ-C107 is FATAL on a data model beside an unstructured format, and
    # chapter 4.5.1 asks for the element to be left out — not for the exchange to
    # be abandoned over a value a conformant directory would never have
    # published there (R-DSD-RESP-C067).
    context 'when the requested format is unstructured' do
      let(:format) { 'application/pdf' }

      it 'is left out, and the request is still built' do
        expect(distribution.element_children.map(&:name)).to eq(%w[Format Language])
      end
    end
  end

  # R-EDM-REQ-C119 closes the list of documents a request may ask for alongside
  # the evidence itself.
  describe 'the associated documents asked for' do
    subject(:requested) do
      Nokogiri::XML(described_class.new(**attributes, associated_documents: asked).render)
        .xpath('//sdg:AssociatedDocumentRequest', 'sdg' => 'http://data.europa.eu/p4s')
    end

    context 'when several are asked for' do
      let(:asked) { [AssociatedDocument::TRANSLATION, AssociatedDocument::ANNEX] }

      it 'writes one element each, in the order they were asked for' do
        expect(requested.map(&:text)).to eq(%w[Translation Annex])
      end

      it 'writes them last in the distribution, where the schema puts them' do
        expect(requested.first.parent.element_children.map(&:name))
          .to eq(%w[Format Language AssociatedDocumentRequest AssociatedDocumentRequest])
      end
    end

    # The element is `0..n`, and every caller but the specimen messages asks for
    # none: an empty one would be a value the rule refuses.
    context 'when none is asked for' do
      let(:asked) { [] }

      it 'writes nothing, rather than an empty element' do
        expect(requested).to be_empty
      end
    end

    # Raised and not written: the values come from this deployment's own code,
    # so an unknown one is a mistake here rather than a message to refuse. At
    # render, where the type builder is constructed — nothing is written by then.
    it 'refuses to render a request asking for a document the rule does not name' do
      expect { described_class.new(**attributes, associated_documents: %w[Résumé]).render }
        .to raise_error(ConfigurationError, /Résumé/)
    end
  end

  it 'omits the eIDAS identifier when the token carried none' do
    anonymous = NaturalPerson.new(family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22')
    rendered = described_class.new(**attributes, beneficiary: anonymous).render

    expect(rendered).not_to include('schemeID="eidas"')
  end

  it 'refuses to build a request for a requester with no usable identity' do
    unusable = EvidenceRequester.new(id: '00000000000002', type_id: '  ')

    expect { described_class.new(**attributes, requester: unusable).render }
      .to raise_error(ConfigurationError, /Le requêteur/)
  end

  # The provider name is read from a directory, and the requester name will one
  # day be read from a message a foreign correspondent sent us.
  it 'escapes a name that would otherwise inject an element' do
    hostile = EvidenceProvider.new(
      identifier: EbmsIdentity.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
      descriptions: { 'EN' => '</sdg:Name><sdg:Injecté/>' },
    )
    rendered = described_class.new(**attributes, provider: hostile).render

    expect(rendered).not_to include('<sdg:Injecté')
    expect(Nokogiri::XML(rendered).errors).to be_empty
  end

  # The wording of a requirement and the title of an evidence type are written
  # by a foreign directory, and nothing vets what a member state publishes there.
  it 'escapes every wording the directories publish' do
    injection = '</sdg:Name><sdg:Injecté/>'
    rendered = described_class.new(
      **attributes,
      requirement: Requirement.new(**attributes[:requirement].attributes.symbolize_keys,
        descriptions: { 'EN' => injection }, details: { 'EN' => injection }),
      data_service: DataService.new(**attributes[:data_service].attributes.symbolize_keys,
        descriptions: { 'EN' => injection }, details: { 'EN' => injection }),
    ).render

    expect(rendered).not_to include('<sdg:Injecté')
    expect(Nokogiri::XML(rendered).errors).to be_empty
  end

  # The two new elements written at once, which nothing else does: each `describe`
  # above exercises one with the other absent, so their relative order rests on
  # the template alone. The XSD sequences them `Format`, `Language*`,
  # `ConformsTo?`, `AssociatedDocumentRequest*`, and a correspondent's parser is
  # entitled to that order.
  it 'writes the data model before the associated documents, as the schema sequences them' do
    structured = build(:data_service,
      distribution_format: 'application/xml',
      distribution_conforms_to: 'https://sr.oots.tech.ec.europa.eu/datamodels/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40')
    rendered = described_class.new(**attributes, data_service: structured,
      associated_documents: [AssociatedDocument::TRANSLATION, AssociatedDocument::ANNEX]).render
    distribution = Nokogiri::XML(rendered).at_xpath('//sdg:DistributedAs', 'sdg' => 'http://data.europa.eu/p4s')

    expect(distribution.element_children.map(&:name))
      .to eq(%w[Format Language ConformsTo AssociatedDocumentRequest AssociatedDocumentRequest])
  end
end
