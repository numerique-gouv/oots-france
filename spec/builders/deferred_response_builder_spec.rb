require 'rails_helper'

RSpec.describe DeferredResponseBuilder do
  subject(:response) { described_class.new(**attributes).render }

  let(:namespaces) do
    {
      'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0',
      'sdg' => 'http://data.europa.eu/p4s',
    }
  end

  let(:attributes) do
    {
      requester: EvidenceRequester.french(id: '00000000000002', name: "Ministère de l'enseignement supérieur"),
      request_id: 'urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797',
      clock: instance_double(Clock, now: '2026-08-06T10:00:00.000Z'),
      uuid: instance_double(UuidGenerator, next: '1a2b3c4d-0000-4000-8000-000000000004'),
    }
  end

  it 'renders the response as the reference message has it' do
    expect(response).to be_equivalent_xml_to(reference_message('reponseDifferee'))
  end

  it 'is well-formed XML' do
    expect(Nokogiri::XML(response).errors).to be_empty
  end

  # `R-EDM-RESP-S006`: the status is what tells a deferral from an answer that
  # carries the document, and nothing else in the body does.
  it 'announces the evidence for later rather than claiming success' do
    expect(Nokogiri::XML(response).root['status'])
      .to eq('urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Unavailable')
  end

  # `R-EDM-RESP-S045` requires the slot; how far ahead it points is stub 10, and
  # is counted from the instant the message names as its own.
  it 'names the date the evidence will be available' do
    announced = Nokogiri::XML(response)
      .at_xpath("//rim:Slot[@name='ResponseAvailableDateTime']//rim:Value", namespaces)

    expect(Time.zone.parse(announced.text))
      .to eq(Time.zone.parse('2026-08-06T10:00:00.000Z') + described_class::DEFERRAL)
  end

  # `R-EDM-RESP-S007` requires the list; chapter 4.5.2 leaves it empty here, for
  # want of anything available.
  it 'carries an empty registry object list' do
    list = Nokogiri::XML(response).at_xpath('//rim:RegistryObjectList', namespaces)

    expect(list).to be_present
    expect(list.element_children).to be_empty
  end

  it 'classifies the answering provider as evidence provider' do
    expect(Nokogiri::XML(response).xpath('//sdg:Classification', namespaces).map(&:text)).to eq(['EP'])
  end

  it 'escapes a requester name read from the request it answers' do
    hostile = EvidenceRequester.french(id: '00000000000002', name: '</sdg:Name><sdg:Injecté/>')
    rendered = described_class.new(**attributes, requester: hostile).render

    expect(rendered).not_to include('<sdg:Injecté')
    expect(Nokogiri::XML(rendered).errors).to be_empty
  end
end
