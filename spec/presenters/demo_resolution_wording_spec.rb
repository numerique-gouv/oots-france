require 'rails_helper'

RSpec.describe DemoResolutionWording do
  subject(:wording) { described_class.new(lookup) }

  let(:provider) { EvidenceProvider.new(descriptions: { 'EN' => 'Keha v. 2.0' }) }
  let(:evidence_type) { EvidenceType.new(descriptions: { 'FR' => 'Justificatif de test' }) }
  let(:lookup) do
    Interactor::Context.build(evidence_type:, data_services: [DataService.new(providers: [provider])])
  end

  # Requirement 27 of chapter 1 §2 asks for these two by name, and for nothing
  # else, before any request is made.
  it 'names the evidence provider and the evidence type' do
    expect(wording).to have_attributes(provider: 'Keha v. 2.0', evidence_type: 'Justificatif de test')
  end

  # `sdg:Publisher` names the organisation, which is what the requirement calls
  # the evidence provider; `sdg:AccessService` names the gateway carrying the
  # message, and is no name for a user to read.
  it 'names the organisation and not its access point' do
    provider.access_point = AccessPoint.new(id: 'AP_FI_03')

    expect(wording.provider).to eq('Keha v. 2.0')
  end

  describe 'what the page may offer to confirm' do
    it 'is offered when both are named' do
      expect(wording).to be_nameable
    end

    it 'is withheld when the chain stopped before the provider' do
      lookup.data_services = nil

      expect(wording).not_to be_nameable
    end

    it 'is withheld when the directory published a nameless provider' do
      provider.descriptions = {}

      expect(wording).not_to be_nameable
    end
  end

  it 'hands on the refusal of whichever step stopped the chain' do
    refused = Interactor::Context.build
    refused.fail!(error: { key: :common_services_refused, errors: ['DSD:ERR:0001'] })
  rescue Interactor::Failure
    expect(described_class.new(refused).failure).to include(key: :common_services_refused)
  end

  it 'has no refusal to hand on when nothing failed' do
    expect(wording.failure).to be_nil
  end
end
