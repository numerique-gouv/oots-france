require 'rails_helper'

RSpec.describe EvidenceRequestBuilder do
  subject(:request) { described_class.new(**attributes).render }

  let(:attributes) do
    {
      requester: EvidenceRequester.french(id: '00000000000002', name: "Ministère de l'enseignement supérieur"),
      provider: EvidenceProvider.new(
        access_point: AccessPoint.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
        descriptions: { 'EN' => 'Civil Registration Office Berlin I' },
      ),
      beneficiary: NaturalPerson.new(
        eidas_identifier: 'FR/DE/123123123', family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22',
      ),
      evidence_type: EvidenceType.new(
        id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
        descriptions: { 'EN' => 'Certificate of Birth' },
        distribution_format: 'application/pdf',
      ),
      procedure_code: ProcedureCode::STUDENT_GRANT,
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
      access_point: AccessPoint.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
      descriptions: { 'EN' => '</sdg:Name><sdg:Injecté/>' },
    )
    rendered = described_class.new(**attributes, provider: hostile).render

    expect(rendered).not_to include('<sdg:Injecté')
    expect(Nokogiri::XML(rendered).errors).to be_empty
  end
end
