require 'rails_helper'

RSpec.describe EvidenceBrokerClient do
  subject(:broker) { described_class.new(query:) }

  let(:query) { instance_double(CommonServicesQuery) }

  it 'asks for the requirements of a procedure in a jurisdiction' do
    allow(query).to receive(:search)
      .and_return(RequirementsResponseParser.new(common_services_answer('eb_requirements_fr').first))

    expect(broker.requirements(procedure_code: '00', country_code: 'FR').map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000'])

    expect(query).to have_received(:search).with(
      { queryId: described_class::REQUIREMENTS_QUERY, 'procedure-id': '00', 'country-code': 'FR' },
      parser: RequirementsResponseParser,
    )
  end

  # Every parameter of that query being optional, one carrying none asks the
  # directory for everything it holds. Sent empty rather than dropped, the
  # parameters would narrow the answer to the procedure named « » in the
  # country « ».
  it 'asks for the whole catalogue by naming neither procedure nor country' do
    allow(query).to receive(:search)
      .and_return(RequirementsResponseParser.new(common_services_answer('eb_requirements_catalogue').first))

    expect(broker.requirements.size).to eq(53)

    expect(query).to have_received(:search).with(
      { queryId: described_class::REQUIREMENTS_QUERY },
      parser: RequirementsResponseParser,
    )
  end

  # Chapter 3.2.4 wants the identifier percent-encoded; Faraday does it, and
  # what matters here is that the value handed over is the bare URI.
  it 'asks for the evidence types satisfying a requirement' do
    allow(query).to receive(:search)
      .and_return(EvidenceTypesResponseParser.new(common_services_answer('eb_evidence_types_fr').first))
    requirement = 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000'

    expect(broker.evidence_types(requirement_id: requirement, country_code: 'FR').map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'])

    expect(query).to have_received(:search).with(
      { queryId: described_class::EVIDENCE_TYPES_QUERY, 'requirement-id': requirement, 'country-code': 'FR' },
      parser: EvidenceTypesResponseParser,
    )
  end

  # `country-code` is optional on this query too: dropped rather than sent
  # empty, it brings back the lists of every country at once.
  it 'asks for the combinations of every country when none is named' do
    allow(query).to receive(:search)
      .and_return(EvidenceTypesResponseParser.new(common_services_answer('eb_evidence_types_fr').first))
    requirement = 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000'

    expect(broker.evidence_type_lists(requirement_id: requirement).map(&:country)).to eq(['FR'])

    expect(query).to have_received(:search).with(
      { queryId: described_class::EVIDENCE_TYPES_QUERY, 'requirement-id': requirement },
      parser: EvidenceTypesResponseParser,
    )
  end
end
