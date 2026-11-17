require 'rails_helper'

# « FR - Student status (MESRI) », served from API Particulier, through the
# whole receiving path: `IncomingMessage::Process` opens the exchange, the
# answer chain matches the person at API Particulier, the preview space and its
# identification decide, and the jobs answer later.
RSpec.describe 'The student status France serves from API Particulier' do
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  STUDENT_CAPTURED_AT = '2026-08-11T09:22:22.000Z'.freeze
  NS = { 'rs' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0', **SlotReading::NAMESPACES }.freeze
  QUERY = ApiParticulierStubs::MARTIN_JACQUES_QUERY

  # Every envelope of this file asks for the student status of Martin Jacques —
  # the second request of a preview included, which is the first one again —,
  # with neither sex nor place unless an example gives them.
  def real_envelope(name)
    document = Nokogiri::XML(super)
    rewrite_body(document) { |body| student_status_body(body, gender: nil, place: nil) }

    document.to_xml
  end

  let(:submitted) { [] }
  let(:gateway) { instance_double(DomibusClient) }

  before do
    travel_to(Time.zone.parse(STUDENT_CAPTURED_AT))
    allow(DomibusClient).to receive(:new).and_return(gateway)
    allow(gateway).to receive(:submit) do |envelope|
      submitted << envelope
      instance_double(SubmittedMessageParser, message_id: "soumis-#{submitted.size}")
    end
  end

  def deliver(message, id)
    allow(gateway).to receive(:retrieve).with(id).and_return(message)
    IncomingMessage::Process.call(message_id: id,
      uuid: Oots::SequentialUuids.new(prefix: "1a2b3c4d-#{id.delete('^0-9').rjust(4, '0')}-4000-8000"))
  end

  def body_of(envelope)
    Nokogiri::XML(Base64.decode64(Nokogiri::XML(envelope).at_xpath('//payload/value').text).force_encoding('UTF-8'))
  end

  def payloads_of(envelope) = Nokogiri::XML(envelope).xpath('//payload')

  def attachment_of(envelope) = Base64.decode64(payloads_of(envelope).last.at_xpath('value').text).force_encoding('UTF-8')

  def answer = body_of(submitted.last)

  def code = answer.at_xpath('//rs:Exception', NS)&.[]('code')

  def text(path) = answer.at_xpath(path, NS)&.text

  def location = PreviewSession.sole.location

  def empty_list?
    answer.root['status'].end_with?('Success') && answer.xpath('/*/rim:RegistryObjectList/*', NS).empty? &&
      payloads_of(submitted.last).size == 1
  end

  def full_query(sex: 'M', place: '75102')
    QUERY.merge('sexeEtatCivil' => sex, 'codeCogInseeCommuneNaissance' => place).compact
  end

  def identity(**overrides)
    Demo::UserIdentity.new(given_name: 'Jacques', family_name: 'Martin', birthdate: '2004-01-01', gender: 'male',
      place_of_birth: '75102', level_of_assurance: 'Substantial', subject: 'sub', id_token: 'jeton',
      france_connect: 'fake', **overrides)
  end

  # `clock`: when the user comes back identified, which dates the evidence the
  # registry then returns.
  def identify(clock: Clock.new, **)
    EvidenceProvision::CheckPreviewIdentity.call(preview_session: PreviewSession.sole, clock:,
      identification: Interactor::Context.build(identity: identity(**)))
  end

  def accept
    perform_enqueued_jobs do
      EvidenceProvision::RecordPreviewDecision.call(preview_session: PreviewSession.sole, decision: 'accepted')
    end
  end

  def recognised_visit
    perform_enqueued_jobs do
      EvidenceProvision::RecordPreviewVisit.call(preview_session: PreviewSession.sole, location:, identified: true)
    end
  end

  def second_exchange(id = 'm002')
    first = Exchange.sole
    perform_enqueued_jobs { deliver(second_request(location:, exchange_id: first.exchange_id), id) }
  end

  describe 'a request carrying the sex and the commune by its code, on the 2.0 line' do
    before do
      stub_student_status
      deliver(student_status_request, 'm001')
    end

    # CA1.
    it 'asks API Particulier for the pivot identity of the request' do
      expect(student_status_asked(full_query)).to have_been_made.once
    end

    it 'serves the object data as API Particulier returned it, in JSON' do
      expect(answer.root['status']).to end_with('Success')
      expect(answer.xpath('//rim:Classification[@classificationNode="MainEvidence"]', NS).size).to eq(1)
      expect(JSON.parse(attachment_of(submitted.last))).to eq(ApiParticulierStubs::MARTIN_JACQUES)
      expect(text('//sdg:Distribution/sdg:Format')).to eq('application/json')
      expect(text('//sdg:Distribution/sdg:Language')).to eq('FR')
      expect(answer.at_xpath('//sdg:Distribution/sdg:ConformsTo', NS)).to be_nil
      expect(answer.at_xpath('//rim:RepositoryItemRef', NS)['xlink:title']).to eq('Statut étudiant')
    end

    it 'declares the part it attaches as JSON' do
      expect(Nokogiri::XML(submitted.last).to_s).to include('<eb:Property name="MimeType">application/json</eb:Property>')
    end

    # CA3.
    it 'names the ministry as the issuer, and the person of the request as the subject' do
      expect(text('//sdg:IssuingAuthority/sdg:Identifier')).to eq('11004401300040')
      expect(answer.xpath('//sdg:IssuingAuthority/sdg:Name', NS).to_h { |name| [name['lang'], name.text] }).to eq(
        'FR' => "Ministère de l'Enseignement supérieur, de la Recherche et de l'Espace",
        'EN' => 'Ministry of Higher Education, Research and Space',
      )
      expect(text('//sdg:IsAbout//sdg:FamilyName')).to eq('Martin')
      expect(text('//sdg:IssuingDate')).to eq('2026-08-11')
      expect(text('//sdg:EvidenceTypeClassification')).to eq(ApiParticulierStubs::STUDENT_STATUS_TYPE)
      expect(answer.at_xpath('//sdg:ValidityPeriod', NS)).to be_nil
    end

    # CA9: the journal keeps what it keeps of any evidence, and nothing of the call.
    it 'journals the JSON it served' do
      expect(AuditEvent.find_by!(event_type: 'response_sent')).to have_attributes(
        evidence_mime_type: 'application/json',
        evidence_content_id: answer.at_xpath('//rim:RepositoryItemRef', NS)['xlink:href'],
        evidence_digest: Digest::SHA256.hexdigest(attachment_of(submitted.last)),
        evidence_identifier: text('//sdg:Evidence/sdg:Identifier'),
      )
      expect(AuditEvent.pluck(:regrep_body).compact.join).not_to include('0330023W')
    end
  end

  # CA1, on the 1.2 line.
  it 'serves the same object on the 1.2 line' do
    stub_student_status
    deliver(student_status_request(line: :v1_2), 'm001')

    expect(answer.root['status']).to end_with('Success')
    expect(JSON.parse(attachment_of(submitted.last))).to eq(ApiParticulierStubs::MARTIN_JACQUES)
    expect(text('//sdg:Distribution/sdg:Language')).to eq('FR')
  end

  # CA2.
  it 'sends the first given name, and reads the sex of code 1' do
    stub_student_status
    deliver(student_status_request(given_name: 'Jean Pierre', gender: '1'), 'm001')

    expect(student_status_asked(full_query.merge('prenoms' => ['Jean']))).to have_been_made.once
    expect(PreviewSession.count).to eq(0)
  end

  # CA13: a place that is no commune by its code is never resolved, and never
  # left out — a person born in France would not be found, and the empty list
  # would be false. The user identifies first.
  ['Nanterre', 'Aarhus', nil].each do |place|
    it "sends the user to identify first, without asking API Particulier, the place #{place.inspect}" do
      deliver(student_status_request(place:), 'm001')

      expect(code).to eq('EDM:ERR:0002')
      expect(student_status_never_asked).not_to have_been_made
      expect(PreviewSession.sole.lookup_pending).to be(true)
    end
  end

  describe 'once the user identifies, the request lacking the place' do
    it 'asks API Particulier with the birthplace and the first given name FranceConnect+ certified' do
      stub_student_status
      deliver(student_status_request(place: 'Aarhus', given_name: 'Jacques Pierre'), 'm001')
      identify(given_name: 'Jacques Pierre')

      expect(student_status_asked(full_query)).to have_been_made.once
    end

    it 'sends no place for a user FranceConnect+ says was born abroad' do
      stub_student_status_unknown
      deliver(student_status_request(place: nil), 'm001')
      identify(place_of_birth: '')

      expect(student_status_asked(full_query(place: nil))).to have_been_made.once
    end
  end

  # CA4.
  describe 'a person API Particulier does not know' do
    before { stub_student_status_unknown }

    [%w[true v2_0], %w[false v2_0], %w[true v1_2], %w[false v1_2]].each do |flag, line|
      it "answers the empty list at once, the flag #{flag}, on the #{line} line" do
        deliver(student_status_request(flag:, line: line.to_sym), 'm001')

        expect(empty_list?).to be(true)
        expect(PreviewSession.count).to eq(0)
      end
    end
  end

  # CA5 and CA6.
  it 'answers EDM:ERR:0008 when API Particulier fails, without a preview' do
    stub_student_status(status: 502, body: '{}')
    deliver(student_status_request(flag: 'true'), 'm001')

    expect(code).to eq('EDM:ERR:0008')
    expect(text('//rim:Slot[@name="PreviewLocation"]//rim:Value')).to be_nil
    expect(Exchange.sole.status).not_to eq('pending')
  end

  it 'answers EDM:ERR:0005 when API Particulier answers late' do
    stub_student_status(status: 504, body: '{}')
    deliver(student_status_request, 'm001')

    expect(code).to eq('EDM:ERR:0005')
  end

  # CA7.
  it 'refuses a request asking for neither JSON nor PDF, without asking API Particulier' do
    deliver(student_status_request(formats: ['application/xml']), 'm001')

    expect(code).to eq('EDM:ERR:0007')
    expect(student_status_never_asked).not_to have_been_made
  end

  it 'serves the data alone to a request asking for both, without asking for the attestation' do
    stub_student_status
    deliver(student_status_request(formats: ['application/json', EvidenceType::PDF]), 'm001')

    expect(text('//sdg:Distribution/sdg:Format')).to eq('application/json')
    expect(a_request(:get, student_status_endpoint).with(headers: ApiParticulierClient::PROOF)).not_to have_been_made
  end

  # CA16.
  describe 'a request asking for the PDF alone' do
    def asking_for_the_attestation(**) = student_status_request(formats: [EvidenceType::PDF], **)

    it 'serves the attestation API Particulier generated, described as such' do
      stub_attested_student_status
      deliver(asking_for_the_attestation, 'm001')

      expect(answer.root['status']).to end_with('Success')
      expect(attachment_of(submitted.last).b).to eq(ApiParticulierStubs::ATTESTATION)
      expect(text('//sdg:Distribution/sdg:Format')).to eq(EvidenceType::PDF)
      expect(text('//sdg:Distribution/sdg:Language')).to eq('FR')
      expect(answer.at_xpath('//sdg:Distribution/sdg:ConformsTo', NS)).to be_nil
      expect(answer.at_xpath('//rim:RepositoryItemRef', NS)['xlink:title']).to eq('Attestation de statut étudiant')
      expect(text('//sdg:IssuingAuthority/sdg:Identifier')).to eq('11004401300040')
      expect(text('//sdg:IssuingDate')).to eq('2026-08-11')
      expect(attestation_downloaded).to have_been_made.once
      expect(AuditEvent.find_by!(event_type: 'response_sent')).to have_attributes(evidence_mime_type: EvidenceType::PDF,
        evidence_digest: Digest::SHA256.hexdigest(ApiParticulierStubs::ATTESTATION))
    end

    it 'serves the same attestation on the 1.2 line' do
      stub_attested_student_status
      deliver(asking_for_the_attestation(line: :v1_2), 'm001')

      expect(answer.root['status']).to end_with('Success')
      expect(attachment_of(submitted.last).b).to eq(ApiParticulierStubs::ATTESTATION)
      expect(text('//sdg:Distribution/sdg:Format')).to eq(EvidenceType::PDF)
    end

    # CA17.
    it 'answers the empty list for a person API Particulier does not know, and EDM:ERR:0008 when it fails' do
      stub_student_status_unknown
      deliver(asking_for_the_attestation, 'm001')
      expect(empty_list?).to be(true)

      stub_student_status(status: 502, body: '{}')
      deliver(asking_for_the_attestation, 'm002')
      expect(code).to eq('EDM:ERR:0008')
    end

    # CA19.
    it 'answers EDM:ERR:0008 without an attachment where the attestation cannot be had' do
      stub_attested_student_status(link: nil)
      deliver(asking_for_the_attestation, 'm001')

      expect(code).to eq('EDM:ERR:0008')
      expect(payloads_of(submitted.last).size).to eq(1)
    end

    it 'answers EDM:ERR:0005 where the attestation does not come in time' do
      stub_attested_student_status
      stub_request(:get, attestation_link).to_raise(Net::ReadTimeout)
      deliver(asking_for_the_attestation, 'm001')

      expect(code).to eq('EDM:ERR:0005')
    end

    # CA18.
    it 'serves the attestation the user saw, downloaded once' do
      stub_attested_student_status
      deliver(asking_for_the_attestation(flag: 'true'), 'm001')
      expect(PreviewSession.sole.document_bytes).to eq(ApiParticulierStubs::ATTESTATION)

      identify
      accept
      travel(1.minute) { second_exchange }

      expect(text('//sdg:Distribution/sdg:Format')).to eq(EvidenceType::PDF)
      expect(attachment_of(submitted.last).b).to eq(ApiParticulierStubs::ATTESTATION)
      expect(attestation_downloaded).to have_been_made.once
    end

    # CA17: the call that follows the identification carries the header.
    describe 'without the sex' do
      before { deliver(asking_for_the_attestation(gender: nil), 'm001') }

      it 'asks for the attestation once the user identifies, and serves it' do
        expect(code).to eq('EDM:ERR:0002')
        stub_attested_student_status
        identify
        accept
        second_exchange

        expect(a_request(:get, student_status_endpoint).with(headers: ApiParticulierClient::PROOF))
          .to have_been_made.once
        expect(text('//sdg:Distribution/sdg:Format')).to eq(EvidenceType::PDF)
        expect(attachment_of(submitted.last).b).to eq(ApiParticulierStubs::ATTESTATION)
      end

      # CA19, after the identification.
      it 'concludes the address where the attestation cannot be had, and answers EDM:ERR:0008' do
        stub_attested_student_status(status: 410)
        identify
        second_exchange

        expect(PreviewSession.sole).to be_unobtainable
        expect(code).to eq('EDM:ERR:0008')
      end
    end
  end

  # CA15: before the distribution, and before the sex.
  it 'refuses a request about an organisation as a type it does not serve' do
    deliver(student_status_request_about_an_organisation, 'm001')
    expect(code).to eq('EDM:ERR:0004')

    deliver(student_status_request_about_an_organisation(formats: [EvidenceType::PDF]), 'm002')
    expect(code).to eq('EDM:ERR:0004')
    expect(student_status_never_asked).not_to have_been_made
  end

  # RG1: `R1` keeps its priority.
  it 'defers the procedure answered later without asking API Particulier' do
    deliver(student_status_request.then do |message|
      document = Nokogiri::XML(message.raw)
      rewrite_body(document) do |body|
        body.sub(/(<rim:Slot name="Procedure">.*?<rim:Value>)[^<]*/m, "\\1#{ProcedureCode::BIRTH_REGISTRATION}")
      end
      RetrievedMessageParser.new(document.to_xml)
    end, 'm001')

    expect(text('//rim:Slot[@name="ResponseAvailableDateTime"]//rim:Value')).to be_present
    expect(student_status_never_asked).not_to have_been_made
  end

  # Chapter 4.4: T1 keeps its priority, over a request without the sex too.
  it 'answers a request past its deadline with the timeout, without asking API Particulier' do
    [student_status_request(flag: 'true'), student_status_request(gender: nil, flag: 'true')].each_with_index do |message, i|
      travel_to(message.sent_at + Settings.provider_timeout + 1.second) { deliver(message, "m00#{i + 1}") }

      expect(code).to eq('EDM:ERR:0005')
    end
    expect(student_status_never_asked).not_to have_been_made
    expect(PreviewSession.count).to eq(0)
  end

  # RG7 before the preview: a failing registry is answered at once, the
  # preview allowed or not.
  it 'refuses a request allowing the preview when API Particulier fails, without a preview' do
    stub_student_status(status: 502, body: '{}')
    deliver(student_status_request(flag: 'true'), 'm001')

    expect(code).to eq('EDM:ERR:0008')
    expect(PreviewSession.count).to eq(0)
  end

  # CA8.
  describe 'a request carrying the sex and the commune by its code, and allowing the preview' do
    before do
      stub_student_status
      deliver(student_status_request(flag: 'true'), 'm001')
    end

    it 'asks API Particulier first, then sends the user to the preview space with what it found' do
      expect(code).to eq('EDM:ERR:0002')
      expect(student_status_asked(full_query)).to have_been_made.once
      expect(JSON.parse(PreviewSession.sole.document_bytes)).to eq(ApiParticulierStubs::MARTIN_JACQUES)
    end

    it 'serves what the user saw, under the identifier and date of the first request, without asking again' do
      evidence_id = PreviewSession.sole.evidence_id
      identify
      accept
      travel(1.minute) { second_exchange }

      expect(answer.root['status']).to end_with('Success')
      expect(text('//sdg:Evidence/sdg:Identifier')).to eq(evidence_id)
      expect(text('//sdg:IssuingDate')).to eq('2026-08-11')
      expect(text('//sdg:IssuingAuthority/sdg:Identifier')).to eq('11004401300040')
      expect(JSON.parse(attachment_of(submitted.last))).to eq(ApiParticulierStubs::MARTIN_JACQUES)
      expect(student_status_asked(full_query)).to have_been_made.once
    end
  end

  # CA12.
  describe 'a request without the sex' do
    ['', 'Unspecified', '0'].product(%w[false true]).each do |gender, flag|
      it "sends the user to identify first, without asking API Particulier, the sex #{gender.inspect}, " \
         "PossibilityForPreview #{flag}" do
        deliver(student_status_request(gender: gender.presence, flag:), 'm001')

        expect(code).to eq('EDM:ERR:0002')
        expect(student_status_never_asked).not_to have_been_made
        expect(PreviewSession.sole).to have_attributes(lookup_pending: true, document: nil, unmatched: false)
      end
    end

    describe 'once the user identifies' do
      before { deliver(student_status_request(gender: nil), 'm001') }

      it 'takes no decision while the status is still to look up' do
        expect(PreviewSession.sole.decide!(accepted: true)).to be_nil
        expect(PreviewSession.sole).to have_attributes(decision: nil, lookup_pending: true)
      end

      it 'asks API Particulier with the sex FranceConnect+ returned, and serves it dated the day of the call' do
        stub_student_status
        identify(clock: Oots::FrozenClock.new(Time.zone.parse('2026-08-12T10:00:00Z')))
        accept
        second_exchange

        expect(student_status_asked(full_query)).to have_been_made.once
        expect(answer.root['status']).to end_with('Success')
        expect(text('//sdg:IssuingDate')).to eq('2026-08-12')
      end

      it 'asks once, whatever the visits' do
        stub_student_status
        identify
        identify
        recognised_visit

        expect(student_status_asked(full_query)).to have_been_made.once
        expect(PreviewSession.sole.lookup_pending).to be(false)
      end

      it 'keeps nothing of the sex' do
        stub_student_status
        identify

        expect(PreviewSession.sole.attributes.values.join).not_to include('male')
      end

      # RG15: the birthplace FranceConnect+ certified is neither kept nor logged.
      it 'keeps nothing of the birthplace FranceConnect+ certified' do
        stub_student_status
        identify(place_of_birth: '2A004')

        expect(PreviewSession.sole.attributes.values.join).not_to include('2A004')
        expect(AuditEvent.all.map(&:attributes).to_s).not_to include('2A004')
      end

      it 'answers the empty list where FranceConnect+ returned no sex, without asking' do
        identify(gender: nil)
        recognised_visit
        second_exchange

        expect(student_status_never_asked).not_to have_been_made
        expect(PreviewSession.sole.unmatched).to be(true)
        expect(empty_list?).to be(true)
      end

      it 'answers the empty list where API Particulier does not know the woman identified' do
        stub_student_status_unknown
        identify(gender: 'female')
        recognised_visit
        second_exchange

        expect(student_status_asked(full_query(sex: 'F'))).to have_been_made.once
        expect(empty_list?).to be(true)
      end

      it 'answers EDM:ERR:0001 to another person, without asking' do
        identify(birthdate: '2004-01-02')
        second_exchange

        expect(student_status_never_asked).not_to have_been_made
        expect(code).to eq('EDM:ERR:0001')
      end
    end
  end

  # CA14.
  describe 'API Particulier failing once the user identified' do
    before { deliver(student_status_request(gender: nil), 'm001') }

    it 'concludes the address, and answers the second request EDM:ERR:0008' do
      stub_student_status(status: 502, body: '{}')
      identify
      second_exchange

      expect(PreviewSession.sole).to have_attributes(status: 'answered', unobtainable: 'EDM:ERR:0008')
      expect(code).to eq('EDM:ERR:0008')
      expect(text('//rim:Slot[@name="PreviewLocation"]//rim:Value')).to be_nil
    end

    it 'answers a second request that came first, as soon as the registry fails' do
      second_exchange
      expect(submitted.size).to eq(1)

      stub_student_status(status: 502, body: '{}')
      perform_enqueued_jobs { identify }

      expect(code).to eq('EDM:ERR:0008')
    end

    it 'answers EDM:ERR:0005 when API Particulier answers late' do
      stub_student_status(status: 504, body: '{}')
      identify
      second_exchange

      expect(code).to eq('EDM:ERR:0005')
    end

    it 'does not ask again on a revisit' do
      stub_student_status(status: 502, body: '{}')
      identify
      identify

      expect(student_status_asked(full_query)).to have_been_made.once
    end
  end
end
