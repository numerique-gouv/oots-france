require 'rails_helper'

RSpec.describe DirectoryLookup::Resolve do
  subject(:lookup) do
    described_class.call(
      evidence_broker:, data_service_directory:,
      procedure_code: '00', country_code: 'FI', requirement_id:, evidence_type_id: nil,
    )
  end

  let(:evidence_broker) do
    instance_double(EvidenceBrokerClient, requirements:, evidence_type_lists: [lists])
  end
  let(:data_service_directory) { instance_double(DataServiceDirectoryClient, data_services: [build(:data_service)]) }

  let(:requirements) do
    [build(:requirement, id: 'https://sr/requirements/aaa'), build(:requirement, id: 'https://sr/requirements/bbb')]
  end
  let(:lists) { build(:evidence_type_list) }
  let(:requirement_id) { nil }

  # The default has to be what a request would have done, which is to keep the
  # first of every list.
  it 'follows the first of each list when nothing is chosen' do
    expect(lookup.requirement.id).to eq('https://sr/requirements/aaa')
    expect(lookup).to be_success
  end

  describe 'when the operator steps aside from that default' do
    let(:requirement_id) { 'bbb' }

    it 'carries on from the requirement chosen' do
      expect(lookup.requirement.id).to eq('https://sr/requirements/bbb')

      expect(evidence_broker).to have_received(:evidence_type_lists)
        .with(requirement_id: 'https://sr/requirements/bbb', country_code: 'FI')
    end
  end

  # The procedure is ours, the evidence types are the asked country's: a page
  # showing the chain has to send what a request sends, or it shows nothing.
  it 'reads the requirements at home and the evidence types in the country asked' do
    lookup

    expect(evidence_broker).to have_received(:requirements)
      .with(procedure_code: '00', country_code: Settings.common_services_country_code)
  end

  # The message says the code first, as `CommonServicesResponseParser` composes
  # it: a double dropping it could not show where the code reaches the page.
  describe 'when a directory refuses' do
    let(:data_service_directory) do
      instance_double(DataServiceDirectoryClient).tap do |double|
        allow(double).to receive(:data_services)
          .and_raise(CommonServicesError.new('DSD:ERR:0001 : rien à donner', code: 'DSD:ERR:0001'))
      end
    end

    # A refusal at the last step must not take the answers already obtained
    # with it: showing them beside the refusal is the whole point of the page.
    #
    # The code travels inside the reason, which is where the page reads it: the
    # alert says the refusal in its title and the directory's own words below.
    it 'keeps what the earlier steps found, and the code the directory named' do
      expect(lookup).to be_failure
      expect(lookup.error[:key]).to eq(:common_services_refused)
      expect(lookup.error[:errors].join).to include('DSD:ERR:0001')
      expect(lookup.requirement.id).to eq('https://sr/requirements/aaa')
      expect(lookup.evidence_type_lists).to eq([lists])
    end
  end

  describe 'when the operator picks another evidence type' do
    subject(:lookup) do
      described_class.call(
        evidence_broker:, data_service_directory:,
        procedure_code: '00', country_code: 'FI', requirement_id: nil, evidence_type_id: 'second',
      )
    end

    let(:lists) do
      build(:evidence_type_list, evidence_types: [
        build(:evidence_type, id: 'https://sr/evidencetypeclassifications/FI/first'),
        build(:evidence_type, id: 'https://sr/evidencetypeclassifications/FI/second'),
      ])
    end

    it 'asks the Data Service Directory about that one' do
      expect(lookup.evidence_type.uuid).to eq('second')

      expect(data_service_directory).to have_received(:data_services)
        .with(evidence_type_classification: 'https://sr/evidencetypeclassifications/FI/second', country_code: 'FI',
          classifications: {})
    end
  end

  # Requirement 26 of chapter 1 §2: where a screen offers the user the
  # combinations, nothing is chosen in their place. Two alternative lists of one
  # type each, as Austria publishes for « (TEST) Test Requirement ».
  describe 'when the caller offers the user the alternatives' do
    subject(:lookup) do
      described_class.call(
        evidence_broker:, data_service_directory:, alternatives_offered: true,
        procedure_code: '00', country_code: 'AT', requirement_id: nil, evidence_type_list_id:, evidence_type_id: nil,
      )
    end

    let(:evidence_broker) do
      instance_double(EvidenceBrokerClient, requirements:, evidence_type_lists: published)
    end
    let(:published) do
      [build(:evidence_type_list, id: 'haute', evidence_types: [build(:evidence_type, id: 'https://sr/AT/high')]),
       build(:evidence_type_list, id: 'basse', evidence_types: [build(:evidence_type, id: 'https://sr/AT/low')])]
    end

    # Chapter 3.2.2 §2.3: « The user can select an 'Evidence Type List'
    # amongst the ones proposed by the Evidence Broker ».
    context 'when one of several combinations is named' do
      let(:evidence_type_list_id) { 'basse' }

      it 'asks the Data Service Directory about its type' do
        expect(lookup).to be_success
        expect(lookup.evidence_type_list.id).to eq('basse')
        expect(data_service_directory).to have_received(:data_services)
          .with(evidence_type_classification: 'https://sr/AT/low', country_code: 'AT', classifications: {})
      end
    end

    context 'when none is named' do
      let(:evidence_type_list_id) { nil }

      it 'chooses none, stops before the Data Service Directory and keeps the lists' do
        expect(lookup).to be_failure
        expect(lookup.error[:key]).to eq(:evidence_type_unchosen)
        expect(lookup.evidence_type).to be_nil
        expect(lookup.evidence_type_lists).to eq(published)
        expect(data_service_directory).not_to have_received(:data_services)
      end
    end

    # The directory changes: a combination remembered on a card may no longer
    # be published, and the card then waits for a choice again.
    context 'when the one named is no longer published' do
      let(:evidence_type_list_id) { 'gone' }

      it 'chooses none' do
        expect(lookup.error[:key]).to eq(:evidence_type_unchosen)
      end
    end

    # Two lists calling on the same types are one combination, whatever
    # jurisdiction tells them apart.
    context 'when the country publishes a single combination' do
      let(:evidence_type_list_id) { nil }
      let(:published) do
        [build(:evidence_type_list, id: 'une', evidence_types: [build(:evidence_type, id: 'https://sr/AT/only')]),
         build(:evidence_type_list, id: 'deux', evidence_types: [build(:evidence_type, id: 'https://sr/AT/only')])]
      end

      it 'keeps the first, there being nothing to choose' do
        expect(lookup).to be_success
        expect(lookup.evidence_type_list.id).to eq('une')
        expect(lookup.evidence_type.id).to eq('https://sr/AT/only')
      end
    end

    context 'when the combination calls on several types' do
      let(:evidence_type_list_id) { 'ensemble' }
      let(:published) do
        [build(:evidence_type_list, id: 'ensemble', evidence_types: [
          build(:evidence_type, id: 'https://sr/AT/high'), build(:evidence_type, id: 'https://sr/AT/low'),
        ])]
      end

      it 'stands on its first type' do
        expect(lookup.evidence_type.id).to eq('https://sr/AT/high')
      end

      it 'stands on the type named, where it is one of them' do
        named = described_class.call(evidence_broker:, data_service_directory:, alternatives_offered: true,
          procedure_code: '00', country_code: 'AT', evidence_type_list_id:, evidence_type_id: 'low')

        expect(named.evidence_type.id).to eq('https://sr/AT/low')
      end
    end
  end

  # Chapter 3.2.4: a country declaring `NoMatch` answered, and the page must
  # keep what it said. The chain stops all the same, the Data Service Directory
  # having no evidence type to be asked about.
  describe 'when the country declares it issues nothing' do
    let(:lists) { build(:evidence_type_list, :no_match) }

    # A declaration is not a refusal either, and the console tells them apart by
    # the key: nothing here carries a code the directory named.
    it 'keeps the declaration on screen and never reaches the last step' do
      expect(lookup).to be_failure
      expect(lookup.error).to include(key: :no_evidence_type, errors: ['FI'])
      expect(lookup.evidence_type_lists.map(&:no_match?)).to eq([true])
      expect(data_service_directory).not_to have_received(:data_services)
    end
  end

  # A refusal in the middle must stop the chain there — the Data Service
  # Directory has nothing to be asked about — while leaving the first answer up.
  describe 'when the middle step refuses' do
    let(:evidence_broker) do
      instance_double(EvidenceBrokerClient, requirements:).tap do |double|
        allow(double).to receive(:evidence_type_lists)
          .and_raise(CommonServicesError.new('EB:ERR:0001 : rien à donner', code: 'EB:ERR:0001'))
      end
    end

    it 'keeps the requirements and never reaches the last step' do
      expect(lookup).to be_failure
      expect(lookup.error[:errors].join).to include('EB:ERR:0001')
      expect(lookup.requirements.map(&:id)).to eq(%w[https://sr/requirements/aaa https://sr/requirements/bbb])
      expect(data_service_directory).not_to have_received(:data_services)
    end
  end

  # An outage is not a refusal: it carries no code, has nothing to show beside
  # the earlier answers, and belongs to the controller, which renders it in 502.
  describe 'when a directory cannot be reached' do
    let(:data_service_directory) do
      instance_double(DataServiceDirectoryClient).tap do |double|
        allow(double).to receive(:data_services)
          .and_raise(CommonServicesError, 'Annuaire injoignable.')
      end
    end

    it 'lets the failure through rather than reporting it as a refusal' do
      expect { lookup }.to raise_error(CommonServicesError, /injoignable/)
    end
  end

  describe 'when the country holds no provider' do
    let(:data_service_directory) { instance_double(DataServiceDirectoryClient, data_services: []) }

    # The directory answers a refusal rather than an empty list, but nothing
    # obliges it to.
    it 'fails, naming the country' do
      expect(lookup).to be_failure
      expect(lookup.error).to eq(key: :no_provider, errors: ['FI'])
    end
  end

  # OOTS-269: `DSD:ERR:0005`, chapter 3.1.4 §4.4.3.3.
  describe 'when the Data Service Directory asks the user a question' do
    subject(:lookup) do
      described_class.call(
        evidence_broker:, data_service_directory:, procedure_code: '00', country_code: 'EL',
        requirement_id: nil, evidence_type_id: nil, provider_classification_answers: answers,
      )
    end

    let(:question) { build(:evidence_provider_classification) }
    let(:asked) { CommonServicesError.new('DSD:ERR:0005 : précision', code: 'DSD:ERR:0005', classifications: [question]) }
    let(:answers) { {} }
    let(:data_service_directory) do
      instance_double(DataServiceDirectoryClient).tap do |double|
        allow(double).to receive(:data_services).and_raise(asked)
        allow(double).to receive(:data_services).with(hash_including(classifications: { question.id => 'TC03' }))
          .and_return([build(:data_service)])
      end
    end

    it 'puts the questions on the context, and asks nothing more without answers' do
      expect(lookup).to be_failure
      expect(lookup.provider_classification_questions).to eq([question])
      expect(data_service_directory).to have_received(:data_services).once
    end

    context 'with an answer to each' do
      let(:answers) { { question.id => 'TC03', 'not-asked' => 'X' } }

      # « MUST use the same evidence-type-classification parameter that was
      # already used for the initial query », « MUST add a new query parameter
      # for every EvidenceProviderClassification element ».
      it 'asks the same query again with an answer per question, and those alone' do
        expect(lookup).to be_success
        expect(data_service_directory).to have_received(:data_services)
          .with(evidence_type_classification: lookup.evidence_type.id, country_code: 'EL',
            classifications: { question.id => 'TC03' })
        expect(lookup.provider_classification_questions).to eq([question])
      end
    end

    context 'with a blank answer' do
      let(:answers) { { question.id => ' ' } }

      it 'asks nothing more' do
        expect(lookup).to be_failure
        expect(data_service_directory).to have_received(:data_services).once
      end
    end

    # Its identifier names a parameter of the query: one that is no UUID is
    # not asked.
    context 'when a question does not describe itself as the chapter requires' do
      let(:question) { build(:evidence_provider_classification, id: 'queryId') }
      let(:answers) { { 'queryId' => 'TC03' } }

      it 'keeps the refusal, and asks nothing' do
        expect(lookup.error).to include(key: :common_services_refused)
        expect(lookup.provider_classification_questions).to be_nil
        expect(data_service_directory).to have_received(:data_services).once
      end
    end

    # RG7: the refusal is said as any other, the questions staying asked.
    context 'when the answered query is refused' do
      let(:answers) { { question.id => 'TC99' } }

      before do
        allow(data_service_directory).to receive(:data_services).with(hash_including(classifications: answers))
          .and_raise(CommonServicesError.new('DSD:ERR:0001 : rien', code: 'DSD:ERR:0001'))
      end

      it 'fails on that refusal, keeping the questions' do
        expect(lookup.error).to include(key: :common_services_refused, nothing_published: true)
        expect(lookup.provider_classification_questions).to eq([question])
      end
    end
  end
end
