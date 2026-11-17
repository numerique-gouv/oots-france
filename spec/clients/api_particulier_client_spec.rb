require 'rails_helper'

RSpec.describe ApiParticulierClient do
  subject(:outcome) { described_class.new.student_status(identity) }

  let(:identity) do
    PivotIdentity.from_france_connect(Demo::UserIdentity.new(family_name: 'Martin', given_name: 'Jacques',
      birthdate: '2004-01-01', place_of_birth: '75102', gender: 'male'))
  end

  # CA1.
  it 'asks for the pivot identity with the bearer token and the recipient' do
    stub_student_status
    outcome

    expect(student_status_asked(ApiParticulierStubs::MARTIN_JACQUES_QUERY.merge(
      'sexeEtatCivil' => 'M', 'codeCogInseeCommuneNaissance' => '75102',
    )).with(headers: { 'Authorization' => "Bearer #{Settings.api_particulier_token}" })).to have_been_made.once
  end

  it 'returns the object data as API Particulier wrote it' do
    stub_student_status

    expect(JSON.parse(outcome.document)).to eq(ApiParticulierStubs::MARTIN_JACQUES)
    expect(outcome.document).to start_with('{"identite":')
  end

  # RG6.
  it 'finds nobody on a 404, nor on a 200 without admission' do
    stub_student_status_unknown
    expect(outcome).to eq(described_class::NotFound.new)

    stub_student_status(data: ApiParticulierStubs::MARTIN_JACQUES.merge('admissions' => []))
    expect(described_class.new.student_status(identity)).to eq(described_class::NotFound.new)
  end

  # RG7.
  [502, 503, 429, 401, 403, 422].each do |status|
    it "answers EDM:ERR:0008 on a #{status}" do
      stub_student_status(status:, body: '{}')

      expect(outcome).to eq(described_class::Unobtainable.new(EdmException::QUERY))
    end
  end

  it 'answers EDM:ERR:0008 on a body it cannot read, and where API Particulier cannot be reached' do
    stub_student_status(body: '<html>')
    expect(outcome.exception).to eq(EdmException::QUERY)

    stub_request(:get, student_status_endpoint).to_raise(Faraday::ConnectionFailed.new('refused'))
    expect(described_class.new.student_status(identity).exception).to eq(EdmException::QUERY)
  end

  # What API Particulier answers on an address it does not serve, read on the
  # sandbox on 2026-11-16: a deployment's mistake, never « nobody found ».
  it 'answers EDM:ERR:0008 on a 404 that is not « Entité non trouvée »' do
    stub_student_status(status: 404, body: 'Cette URL n\'existe pas sur API particulier, veuillez vérifier votre URL.')

    expect(outcome).to eq(described_class::Unobtainable.new(EdmException::QUERY))
  end

  it 'answers EDM:ERR:0008 on a data the preview space could not show' do
    stub_student_status(data: ApiParticulierStubs::MARTIN_JACQUES.merge('identite' => nil))
    expect(outcome.exception).to eq(EdmException::QUERY)

    admission = ApiParticulierStubs::MARTIN_JACQUES['admissions'].first
    [['0330023W'], [admission.except('est_inscrit')], [admission.merge('etablissement_etudes' => '0330023W')],
     [admission.merge('regime_formation' => 'formation initiale')]].each do |admissions|
      stub_student_status(data: ApiParticulierStubs::MARTIN_JACQUES.merge('admissions' => admissions))
      expect(described_class.new.student_status(identity).exception).to eq(EdmException::QUERY)
    end
  end

  it 'answers EDM:ERR:0008 on a 404 whose body is no object' do
    stub_student_status(status: 404, body: 'null')

    expect(outcome).to eq(described_class::Unobtainable.new(EdmException::QUERY))
  end

  it 'warns the log of every failure, with its cause and nothing of the body' do
    allow(Rails.logger).to receive(:warn)
    stub_student_status(status: 502, body: '{"nom":"Martin"}')
    outcome

    expect(Rails.logger).to have_received(:warn).with(a_string_including('502', 'EDM:ERR:0008')
      .and(satisfy { |line| line.exclude?('Martin') }))
  end

  # CA5: the operator alone can renew a token.
  it 'logs a token refused as an error, every request failing with it' do
    allow(Rails.logger).to receive(:error)
    stub_student_status(status: 401, body: '{}')
    outcome

    expect(Rails.logger).to have_received(:error).with(a_string_including('401', 'jeton'))
  end

  # RG8.
  it 'answers EDM:ERR:0005 on a 504, and where the answer does not come in time' do
    stub_student_status(status: 504, body: '{}')
    expect(outcome.exception).to eq(EdmException::TIMEOUT)

    # A read timeout: one on opening the connection is an API Particulier that
    # cannot be reached, and answered EDM:ERR:0008 above.
    stub_request(:get, student_status_endpoint).to_raise(Net::ReadTimeout)
    expect(described_class.new.student_status(identity).exception).to eq(EdmException::TIMEOUT)
  end

  it 'waits fifteen seconds at most' do
    expect(described_class.new.send(:connection).options).to have_attributes(timeout: 15, open_timeout: 15)
  end

  # RG18.
  describe 'asked for the attestation' do
    subject(:outcome) { described_class.new.student_status(identity, attestation: true) }

    it 'asks with X-Generate-Proof, and downloads the attestation without the token' do
      stub_attested_student_status

      expect(outcome).to have_attributes(attestation: ApiParticulierStubs::ATTESTATION)
      expect(JSON.parse(outcome.document)).to eq(ApiParticulierStubs::MARTIN_JACQUES)
      expect(a_request(:get, student_status_endpoint).with(headers: described_class::PROOF)).to have_been_made.once
      expect(attestation_downloaded.with { |request| !request.headers.key?('Authorization') }).to have_been_made.once
    end

    it 'finds nobody on a 404, without an attestation' do
      stub_student_status_unknown

      expect(outcome).to eq(described_class::NotFound.new)
    end

    # CA19.
    it 'answers EDM:ERR:0008 without a link, as production answers' do
      stub_attested_student_status(link: nil)

      expect(outcome).to eq(described_class::Unobtainable.new(EdmException::QUERY))
    end

    it 'answers EDM:ERR:0008 on a link answering anything but 200, or anything but a PDF' do
      stub_attested_student_status(status: 410)
      expect(outcome.exception).to eq(EdmException::QUERY)

      stub_attested_student_status(pdf: '<html>expired</html>')
      expect(described_class.new.student_status(identity, attestation: true).exception).to eq(EdmException::QUERY)
    end

    it 'answers EDM:ERR:0008 on an attestation over 25 MB' do
      stub_attested_student_status(pdf: "%PDF-1.5\n#{'x' * described_class::MAX_ATTESTATION_SIZE}")
      allow(Rails.logger).to receive(:warn)

      expect(outcome.exception).to eq(EdmException::QUERY)
      expect(Rails.logger).to have_received(:warn).with(include('attestation_too_large'))
    end

    it 'answers EDM:ERR:0005 on a link that does not answer in time' do
      stub_attested_student_status
      stub_request(:get, attestation_link).to_raise(Net::ReadTimeout)

      expect(outcome.exception).to eq(EdmException::TIMEOUT)
    end

    [
      'http://staging.particulier.api.gouv.fr/api/attestations/a',
      'https://particulier.example.org/api/attestations/a',
      'https://staging.particulier.api.gouv.fr.example.org/api/attestations/a',
      'https://staging.particulier.api.gouv.fr:8443/api/attestations/a',
      'https://staging.particulier.api.gouv.fr@example.org/api/attestations/a',
      'https://exa mple.org/a',
    ].each do |link|
      it "follows no link but to the host it called, over HTTPS: #{link}" do
        stub_attested_student_status(link: nil)
        stub_request(:get, student_status_endpoint).to_return(
          body: { data: ApiParticulierStubs::MARTIN_JACQUES, links: { attestation_pdf: link } }.to_json,
        )

        expect(outcome).to eq(described_class::Unobtainable.new(EdmException::QUERY))
        expect(a_request(:get, /example\.org|:8443|http:/)).not_to have_been_made
      end
    end

    # RG21: fifteen seconds for the whole download, not for each read.
    it 'answers EDM:ERR:0005 on an attestation still arriving after fifteen seconds' do
      stub_attested_student_status
      client = described_class.new
      allow(client).to receive(:monotonic).and_return(0.0, 16.0)

      expect(client.student_status(identity, attestation: true).exception).to eq(EdmException::TIMEOUT)
    end

    it 'downloads within the same delay' do
      expect(described_class.new.send(:attestation_connection).options).to have_attributes(timeout: 15, open_timeout: 15)
    end

    it 'keeps the link out of the log' do
      stub_attested_student_status(status: 410)
      allow(Rails.logger).to receive(:warn)
      outcome

      expect(Rails.logger).to have_received(:warn).with(satisfy { |line| line.exclude?('attestations') })
    end
  end

  it 'asks without X-Generate-Proof for the data' do
    stub_student_status
    outcome

    expect(a_request(:get, student_status_endpoint).with { |request| !request.headers.key?('X-Generate-Proof') })
      .to have_been_made.once
  end
end
