require 'rails_helper'

RSpec.describe SystemCheckResponseBuilder do
  subject(:response) { described_class.new(**attributes).render }

  XSI = 'http://www.w3.org/2001/XMLSchema-instance'.freeze
  XLINK = 'http://www.w3.org/1999/xlink'.freeze

  let(:namespaces) do
    {
      'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0',
      'sdg' => 'http://data.europa.eu/p4s',
      'xlink' => 'http://www.w3.org/1999/xlink',
    }
  end

  let(:attributes) do
    {
      requester: EvidenceRequester.french(id: '00000000000002', name: "Ministère de l'enseignement supérieur"),
      beneficiary: NaturalPerson.new(
        eidas_identifier: 'FR/DE/123123123', family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22',
      ),
      evidence_type: EvidenceType.new(
        id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
        descriptions: { 'EN' => 'Certificate of Birth' },
        distribution_format: 'application/pdf',
      ),
      attachment: Attachment.new('cid:1a2b3c4d-0000-4000-8000-000000000003@pdf.oots.fr', 'JVBERi0='),
      request_id: 'urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797',
      clock: instance_double(Clock, now: '2026-08-06T10:00:00.000Z'),
      uuid: sequential_uuids,
    }
  end

  it 'renders the response as the reference message has it' do
    expect(response).to be_equivalent_xml_to(reference_message('reponse'))
  end

  it 'is well-formed XML' do
    expect(Nokogiri::XML(response).errors).to be_empty
  end

  it 'classifies the answering provider as evidence provider' do
    expect(Nokogiri::XML(response).xpath('//sdg:Classification', namespaces).map(&:text)).to eq(['EP'])
  end

  # The TDD make the provider a collection on a response and a single value on
  # a request, and the reverse for the requester. Asserted because it is exactly
  # the kind of asymmetry a port quietly straightens out.
  it 'puts the provider in a collection and the requester in a single value' do
    document = Nokogiri::XML(response)
    provider = document.at_xpath('//rim:Slot[@name="EvidenceProvider"]/rim:SlotValue', namespaces)
    requester = document.at_xpath('//rim:Slot[@name="EvidenceRequester"]/rim:SlotValue', namespaces)

    expect(namespaced_attribute(provider, 'type', XSI)).to eq('rim:CollectionValueType')
    expect(namespaced_attribute(requester, 'type', XSI)).to eq('rim:AnyValueType')
  end

  # This is what ties the metadata to the bytes: the reference must name the
  # very payload the ebMS header declares.
  it 'points the repository item at the attachment carried alongside' do
    reference = Nokogiri::XML(response).at_xpath('//rim:RepositoryItemRef', namespaces)

    expect(namespaced_attribute(reference, 'href', XLINK)).to eq('cid:1a2b3c4d-0000-4000-8000-000000000003@pdf.oots.fr')
    expect(namespaced_attribute(reference, 'title', XLINK)).to eq('Evidence')
  end

  it 'marks the evidence as the main one of the package' do
    classification = Nokogiri::XML(response).at_xpath('//rim:Classification', namespaces)

    expect(classification['classificationNode']).to eq('MainEvidence')
  end

  it 'omits the eIDAS identifier when the request carried none' do
    anonymous = NaturalPerson.new(family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22')
    rendered = described_class.new(**attributes, beneficiary: anonymous).render

    expect(rendered).not_to include('schemeID="eidas"')
  end

  it 'escapes a requester name read from the request it answers' do
    hostile = EvidenceRequester.french(id: '00000000000002', name: '</sdg:Name><sdg:Injecté/>')
    rendered = described_class.new(**attributes, requester: hostile).render

    expect(rendered).not_to include('<sdg:Injecté')
    expect(Nokogiri::XML(rendered).errors).to be_empty
  end

  # `node['href']` only finds an attribute without a namespace. These carry one,
  # and reading them nakedly returns nil — which would have made the assertion
  # pass against an attribute that is not there at all.
  def namespaced_attribute(node, name, namespace) = node.attribute_with_ns(name, namespace)&.value

  def sequential_uuids
    compteur = 3
    instance_double(UuidGenerator).tap do |generator|
      allow(generator).to receive(:next) { format('1a2b3c4d-0000-4000-8000-%012d', compteur += 1) }
    end
  end
end
