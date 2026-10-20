require 'rails_helper'

RSpec.describe Demo::RequestCombination do
  subject(:requested) do
    described_class.call(identity: :identity, journey: :journey, requirement_uuid: 'exigence', procedure: {},
      named_evidences: %w[premier second troisieme].map { |uuid| Demo::NamedEvidence.new(evidence_type_id: "https://sr/EL/#{uuid}") })
  end

  # `R-EDM-REQ-S015`: one `EvidenceRequest` per query, so one request per type,
  # in the order of the combination; a refusal stops those after it.
  it 'asks for each type in order, and stops at the first refusal, which it hands back by type' do
    asked = []
    allow(Demo::RequestEvidence).to receive(:call) do |**context|
      asked << context[:evidence_type_id]
      Interactor::Context.new.tap do |result|
        result.fail!(error: :refus) if context[:evidence_type_id].end_with?('second')
      rescue Interactor::Failure
        result
      end
    end

    expect(requested.failures).to eq('second' => :refus)
    expect(asked).to eq(%w[https://sr/EL/premier https://sr/EL/second])
    expect(requested).to be_success
  end
end
