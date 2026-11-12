# A copy of the directories built on the captured answers of
# `spec/fixtures/common_services/`, keyed as the production sweep keys them.
#
# Two requirements: the test requirement, published by Austria, Greece and
# Finland and declared `NoMatch` by France; and a second one the Evidence Broker
# refuses with `EB:ERR:0001`. The copy is not checked against any signature, so
# the Evidence Broker answer gathering four countries is built here from the
# four captures, which each carry one.
#
# The captures are those of the acceptance's smoke-test requirements, which the
# public page hides by their identifiers — the nil and the max UUID: those are
# moved to ordinary ones. `smoke_tests: true` keeps them as captured.
module DirectorySnapshots
  LIST = %r{<sdg:EvidenceTypeList>.*?</sdg:EvidenceTypeList>}m

  REQUIREMENT = 'https://sr.acc.oots.tech.ec.europa.eu/requirements/5c1d7e2a-3b4f-4a8e-9d6c-1e2f3a4b5c6d'.freeze
  EMPTY_REQUIREMENT = 'https://sr.acc.oots.tech.ec.europa.eu/requirements/8e7f6a5b-4c3d-4e2f-8a1b-9c8d7e6f5a4b'.freeze
  DISGUISED = {
    '00000000-0000-0000-0000-000000000000' => REQUIREMENT.split('/').last,
    'ffffffff-ffff-ffff-ffff-ffffffffffff' => EMPTY_REQUIREMENT.split('/').last,
  }.freeze

  # What the Data Service Directory answered for each evidence type, by the
  # first segment of its UUID: services for Austria and the simple Greek type, a
  # question about the user for the Projectathon one, nothing for Finland.
  DATA_SERVICES = {
    'cb10c17a' => 'dsd_data_services_at_cb10c17a',
    '198ab7cc' => 'dsd_data_services_at_198ab7cc',
    '8b0aeabd' => 'dsd_data_services_el_8b0aeabd',
    '8b3b6a31' => 'dsd_classification_requise_el_8b3b6a31',
    '19f0783e' => 'dsd_aucun_service_fr',
  }.freeze

  def take_snapshot(taken_at: Time.zone.local(2026, 11, 8, 2, 43), data_services: {}, smoke_tests: false)
    DirectorySnapshot.record!(snapshot_answers(data_services:, smoke_tests:), taken_at:)
  end

  def snapshot_answers(data_services: {}, smoke_tests: false)
    shown = smoke_tests ? :itself.to_proc : method(:disguised)
    evidence_types = shown.call(evidence_types_of_four_countries)

    evidence_broker_answers(shown, evidence_types, smoke_tests)
      .merge(data_service_answers(evidence_types, DATA_SERVICES.merge(data_services)))
  end

  def evidence_broker_answers(shown, evidence_types, smoke_tests)
    requirement, empty_requirement = smoke_tests ? DISGUISED.keys.map { "#{REQUIREMENT[%r{.*/}]}#{it}" } : [REQUIREMENT, EMPTY_REQUIREMENT]

    {
      snapshot_key({ queryId: EvidenceBrokerClient::REQUIREMENTS_QUERY }) =>
        shown.call(common_services_answer('eb_requirements_deux_fr').first),
      evidence_types_key(requirement) => evidence_types,
      evidence_types_key(empty_requirement) => common_services_answer('eb_requirements_vides').first,
    }
  end

  PRODUCTION = 'https://query.cs.oots.tech.ec.europa.eu'.freeze

  PRODUCTION_SEARCH = %r{\A#{Regexp.escape(PRODUCTION)}/(eb|dsd)/rest/search}

  # The production directories, found through their NAPTR records and answering
  # what `answers` holds for each question — so that a sweep reading them all
  # records exactly that copy. The signature is doubled: the captures are signed
  # by the acceptance instance, which the production trust store refuses.
  # Answers the resolver, which a spec asks what names it was given.
  def serve_production_directories(answers = snapshot_answers)
    resolver = stub_production_resolution
    allow(CommonServicesSignature).to receive(:new).with(trust_store_path: Directories::ProductionSweep::TRUST_STORE)
      .and_return(instance_double(CommonServicesSignature, verify!: true))
    stub_request(:get, PRODUCTION_SEARCH).to_return { |request| { body: answers.fetch(asked_key(request)) } }

    resolver
  end

  def asked_key(request) = snapshot_key(WebMock::Util::QueryMapper.query_to_values(request.uri.query))

  def stub_production_resolution
    resolver = instance_double(Resolv::DNS)
    allow(Resolv::DNS).to receive(:open).and_yield(resolver)
    allow(resolver).to receive(:getresources) do |name, _type|
      service = name[/\A\w+\.(\w+)\./, 1]
      [Resolv::DNS::Resource::IN::NAPTR.new(100, 10, 'U', '', "!.*!#{PRODUCTION}/#{service}/!",
        Resolv::DNS::Name.create('.'))]
    end

    resolver
  end

  # The captured refusal, its code changed: no capture holds a `DSD:ERR:0002`.
  def unknown_evidence_type_answer
    common_services_answer('dsd_aucun_service_fr').first.sub('DSD:ERR:0001', 'DSD:ERR:0002')
  end

  private

  def disguised(body)
    DISGUISED.reduce(body) { |found, (captured, moved)| found.gsub(captured, moved) }
  end

  def snapshot_key(parameters) = DirectorySnapshot::Answer.key(parameters)

  def evidence_types_key(requirement)
    snapshot_key({ queryId: EvidenceBrokerClient::EVIDENCE_TYPES_QUERY, 'requirement-id': requirement })
  end

  def data_service_answers(evidence_types, fixtures)
    pairs = EvidenceTypesResponseParser.new(evidence_types).evidence_type_lists
      .flat_map { |list| list.evidence_types.map { |type| [type.id, list.country] } }.uniq

    pairs.to_h { |type, country| [data_services_key(type, country), fixture_body(fixtures.fetch(type.split('/').last[0, 8]))] }
  end

  # A capture's name, or a body built beside the captures.
  def fixture_body(answer) = answer.start_with?('<') ? answer : common_services_answer(answer).first

  def data_services_key(type, country)
    parameters = { queryId: DataServiceDirectoryClient::DATA_SERVICES_QUERY,
                   'evidence-type-classification': type, 'country-code': country }

    snapshot_key(parameters)
  end

  def evidence_types_of_four_countries
    austria = common_services_answer('eb_evidence_types_at').first
    others = [common_services_answer('eb_evidence_types_el').first, common_services_answer('eb_evidence_types_fi').first,
              evidence_types_declaring_no_match(reason: 'No such evidence in France')]
    last_list = austria.scan(LIST).last

    austria.sub(last_list) { last_list + others.flat_map { |body| body.scan(LIST) }.join }
  end
end
