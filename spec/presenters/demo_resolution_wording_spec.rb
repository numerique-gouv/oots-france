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

  # The card stands under the requirement, and it is the requirement the
  # directories named — in English first, where the console reads French first:
  # this page is the portal, and its reader is a user of another Member State.
  describe 'what the card stands under' do
    subject(:wording) { described_class.new(lookup) }

    let(:descriptions) { { 'FR' => 'Preuve de scolarité', 'EN' => 'Proof of enrolment' } }
    let(:requirement) { Requirement.new(descriptions:) }
    let(:lookup) do
      Interactor::Context.build(
        evidence_type:, data_services: [DataService.new(providers: [provider])], requirement:,
      )
    end

    it 'is the requirement, in English where the directory published both' do
      expect(wording).to have_attributes(requirement: 'Proof of enrolment', requirement_language: 'EN')
    end

    context 'when the directory published French alone' do
      let(:descriptions) { { 'FR' => 'Preuve de scolarité' } }

      it 'stands under that French, and says so' do
        expect(wording).to have_attributes(requirement: 'Preuve de scolarité', requirement_language: 'FR')
      end
    end

    # A requirement the directory named in no language at all leaves the card
    # headless, so the evidence type that satisfies it stands in — and the
    # language declared is that value's own: one describing the requirement
    # while the evidence type is shown would be worse than none.
    context 'when the directory named it in no language' do
      let(:descriptions) { {} }

      it 'falls back on the evidence type, and on that value\'s language' do
        expect(wording).to have_attributes(requirement: 'Justificatif de test', requirement_language: 'FR')
      end
    end

    context 'when no requirement was reached at all' do
      let(:requirement) { nil }

      it 'falls back on the evidence type, and on that value\'s language' do
        expect(wording).to have_attributes(requirement: 'Justificatif de test', requirement_language: 'FR')
      end
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

  # The card says « aucun fournisseur listé » on the refusal chapters 3.2.4 and
  # 3.1.4 reserve for it, and on nothing else. What it reads is the answer the
  # directory gave, carried on the failure as data: the French sentence composed
  # from that answer is a wording, and a wording is rewritten.
  describe 'whether nobody publishes this here' do
    def wording_for(failure)
      refused = Interactor::Context.build
      refused.fail!(error: failure)
    rescue Interactor::Failure
      described_class.new(refused)
    end

    it 'is said of the refusal the directories reserve for it' do
      expect(wording_for(key: :common_services_refused, errors: ['DSD:ERR:0001 : rien de publié'],
        nothing_published: true)).to be_published_nothing
    end

    it 'is not said of a directory declining to answer' do
      expect(wording_for(key: :common_services_refused, errors: ['DSD:ERR:0003 : paramètre absent'],
        nothing_published: false)).not_to be_published_nothing
    end

    it 'is said of a step that came back with an empty list' do
      expect(wording_for(key: :no_provider, errors: [])).to be_published_nothing
    end

    # The point of the whole arrangement: rewrite the sentence, the card is
    # unmoved.
    it 'does not change when the French wording of the refusal is rewritten' do
      expect(wording_for(key: :common_services_refused, nothing_published: true,
        errors: ['Aucun fournisseur ne publie ce justificatif dans ce pays.'])).to be_published_nothing
    end
  end
end
