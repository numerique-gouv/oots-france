require 'rails_helper'

RSpec.describe ErrorResponseBuilder do
  subject(:response) { described_class.new(**attributes).render }

  let(:namespaces) do
    {
      'rim' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0',
      'rs' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0',
      'sdg' => 'http://data.europa.eu/p4s',
    }
  end

  let(:attributes) do
    {
      requester: EvidenceRequester.french(id: '00000000000002', name: "Ministère de l'enseignement supérieur"),
      exception: EdmException::OBJECT_NOT_FOUND,
      request_id: 'urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797',
      clock: instance_double(Clock, now: '2026-08-06T10:00:00.000Z'),
      uuid: instance_double(UuidGenerator, next: '1a2b3c4d-0000-4000-8000-000000000007'),
    }
  end

  # One per code the repository emits, because the exception type changes with
  # the code and the rules constrain it: a code never produced here is a code
  # never confronted with the rules.
  {
    'erreur' => EdmException::OBJECT_NOT_FOUND,
    'erreurRequeteInvalide' => EdmException::INVALID_REQUEST,
    'erreurCapaciteNonSupportee' => EdmException::UNSUPPORTED_CAPABILITY,
    'erreurExpiration' => EdmException::TIMEOUT,
  }.each do |fixture, exception|
    it "renders the #{exception.code} response as the reference message has it" do
      rendered = described_class.new(**attributes, exception:).render

      expect(rendered).to be_equivalent_xml_to(reference_message(fixture))
    end
  end

  it 'is well-formed XML' do
    expect(Nokogiri::XML(response).errors).to be_empty
  end

  # Optional per chapter 4.5.3, so written only when there is one: an empty
  # attribute would say a diagnosis was attempted and yielded nothing.
  describe 'the detail attribute' do
    subject(:exception_element) { Nokogiri::XML(response).at_xpath('//rs:Exception', namespaces) }

    it 'is absent when the exception carries no detail' do
      expect(exception_element.attribute('detail')).to be_nil
    end

    context 'when the exception names the rule it refused' do
      let(:attributes) { super().merge(exception: EdmException::INVALID_REQUEST.with_detail('R-EDM-REQ-S016')) }

      it 'writes it beside the code' do
        expect(exception_element['detail']).to eq('R-EDM-REQ-S016')
      end

      it 'keeps the message the code list fixes' do
        expect(exception_element['message']).to eq(EdmException::INVALID_REQUEST.message)
      end
    end
  end

  # The corners swap: on a request the requester is C1, here it is us who
  # answer, and we are classified ERRP rather than EP — an error is not a
  # delivery.
  it 'classifies the answering provider as error provider, and the requester not at all' do
    document = Nokogiri::XML(response)

    expect(document.xpath('//sdg:Classification', namespaces).map(&:text)).to eq(['ERRP'])
  end

  it 'gives an address to the provider answering, and none to the requester' do
    document = Nokogiri::XML(response)
    requester = document.at_xpath('//rim:Slot[@name="EvidenceRequester"]', namespaces)

    expect(document.xpath('//sdg:Address', namespaces).size).to eq(1)
    expect(requester.xpath('.//sdg:Address', namespaces)).to be_empty
  end

  it 'echoes the identifier of the request it answers' do
    expect(Nokogiri::XML(response).root['requestId'])
      .to eq('urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797')
  end

  describe 'the preview location' do
    # R-EDM-ERR-C022 ties the slot to the PreviewRequired severity: without
    # it, EDM:ERR:0002 cannot be emitted at all.
    it 'is emitted when the exception carries one' do
      rendered = described_class.new(
        **attributes,
        exception: EdmException::AUTHORIZATION,
        preview_location: 'https://previsualisation.example.fr/espace?jeton=abc',
      ).render
      slot = Nokogiri::XML(rendered).at_xpath('//rim:Slot[@name="PreviewLocation"]//rim:Value', namespaces)

      expect(slot.text).to eq('https://previsualisation.example.fr/espace?jeton=abc')
    end

    it 'is absent otherwise, rather than emitted empty' do
      expect(response).not_to include('PreviewLocation')
    end
  end

  it 'escapes a requester name read from the message that asked' do
    hostile = EvidenceRequester.french(id: '00000000000002', name: '"/><sdg:Injecté/>')
    rendered = described_class.new(**attributes, requester: hostile).render

    expect(rendered).not_to include('<sdg:Injecté')
    expect(Nokogiri::XML(rendered).errors).to be_empty
  end
end
