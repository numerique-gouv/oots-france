require 'rails_helper'

RSpec.describe EvidenceTypesResponseParser do
  subject(:evidence_types) { described_class.new(body).evidence_types }

  let(:body) { common_services_answer('eb_evidence_types_fr').first }

  # The answer is already restricted to the jurisdiction asked for: the French
  # query returns the French list and not those of the other member states
  # pointing at the same shared requirement.
  it 'reads the evidence types of the jurisdiction queried' do
    expect(evidence_types.map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'])
  end

  it 'keeps the titles the directory publishes' do
    expect(evidence_types.first.descriptions).to include('EN' => 'FR - Test Evidence Type')
  end

  # An unstructured evidence type declares no format, and the model's default
  # is what the rest of the chain expects.
  it 'leaves the distribution format to its default when none is declared' do
    expect(evidence_types.first.distribution_format).to eq(EvidenceType::PDF)
  end

  # The Finnish answer to the same requirement, and the type the DSD fixture
  # answers for: reading it here is what ties the two halves of the chain to
  # the same real exchange.
  it 'reads the Finnish type the data service directory then resolves' do
    finnish = described_class.new(common_services_answer('eb_evidence_types_fi').first)

    expect(finnish.evidence_types.map(&:id))
      .to eq(['https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/19f0783e-7cdc-4146-9ff9-e331514ffb74'])
  end

  it 'refuses a requirement carrying no evidence type' do
    stripped = body.gsub(%r{<sdg:EvidenceTypeList>.*</sdg:EvidenceTypeList>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  # Left unvalidated, the type would travel as far as the
  # `EvidenceTypeClassification` slot of an outgoing request and go out empty.
  it 'refuses an entry the directory published without a classification' do
    stripped = body.sub(%r{<sdg:EvidenceTypeClassification>.*?</sdg:EvidenceTypeClassification>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /annoncé par l'annuaire/)
  end

  # Several lists are alternatives to one another, and several types within a
  # list are needed together; the answer for France carries one of each, so the
  # flattening is exercised on a hand-built body.
  it 'flattens the types of every list the requirement carries' do
    expect(described_class.new(two_lists).evidence_types.map(&:id)).to eq(%w[https://sr/premier https://sr/second])
  end

  def two_lists
    body.sub(%r{(<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>)}m) do
      one = Regexp.last_match(1)
      [one.sub(%r{(<sdg:EvidenceTypeClassification>).*?(</sdg:EvidenceTypeClassification>)}m, '\1https://sr/premier\2'),
       one.sub(%r{(<sdg:EvidenceTypeClassification>).*?(</sdg:EvidenceTypeClassification>)}m, '\1https://sr/second\2')]
        .join
    end
  end
end
