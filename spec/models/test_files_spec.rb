require 'rails_helper'

RSpec.describe TestFiles do
  let(:conversation_id) { '5fe50e16-d6b8-4005-b5ec-0ab097f34319' }
  let(:start) { Time.zone.parse('2026-11-24 10:00') }

  def exchange(country_code, incoming: false, opened: 0)
    create(:exchange, conversation_id:, country_code:, incoming:, created_at: start + opened.minutes)
  end

  def message(exchange, event_type, minute:, header: "<header #{event_type} #{minute}/>", body: "<body #{event_type} #{minute}/>")
    create(:audit_event, exchange_id: exchange.exchange_id, conversation_id:, event_type:,
      occurred_at: start + minute.minutes, ebms_header: header, regrep_body: body)
  end

  def test_files(run: '01')
    described_class.new(Exchange.where(conversation_id:).order(:created_at).includes(:audit_events),
      test_case: 'TC06', run:)
  end

  def names = test_files.map(&:name)

  describe 'a preview France asks of Estonia' do
    let(:estonia) { exchange('EE') }

    before do
      message(estonia, 'request_sent', minute: 1)
      message(estonia, 'error_received', minute: 2, body: '<rs:QueryResponse><rs:Exception code="EDM:ERR:0002"/></rs:QueryResponse>')
      message(estonia, 'request_sent', minute: 3)
      message(estonia, 'return_to_procedure', minute: 4)
      message(estonia, 'response_received', minute: 5)
      message(estonia, 'evidence_delivered', minute: 6)
    end

    it 'names the eight files of the two round trips, and nothing of the other events' do
      expect(names).to eq(%w[
        FREE-TC06-01_HReq1.xml FREE-TC06-01_EvReq1.xml
        FREE-TC06-01_HRes1.xml FREE-TC06-01_EvRes1.xml
        FREE-TC06-01_HReq2.xml FREE-TC06-01_EvReq2.xml
        FREE-TC06-01_HRes2.xml FREE-TC06-01_EvRes2.xml
      ])
    end

    it 'gives each file the part as the journal kept it, a one-line body included' do
      error = AuditEvent.find_by(event_type: 'error_received')
      contents = test_files.to_h { [it.name, it.content] }

      expect(contents['FREE-TC06-01_HRes1.xml']).to eq(error.ebms_header)
      expect(contents['FREE-TC06-01_EvRes1.xml'])
        .to eq('<rs:QueryResponse><rs:Exception code="EDM:ERR:0002"/></rs:QueryResponse>')
    end

    it 'names the archive after the test identifier' do
      expect(test_files.archive_name).to eq('FREE-TC06-01.zip')
    end
  end

  it 'draws only the part the journal recorded' do
    message(exchange('BE'), 'request_sent', minute: 1, header: nil)

    expect(names).to eq(%w[FRBE-TC06-01_EvReq1.xml])
  end

  it 'puts the requester first where France provides' do
    sweden = exchange('SE', incoming: true)
    message(sweden, 'request_received', minute: 1)
    message(sweden, 'error_sent', minute: 2)
    message(sweden, 'response_sent', minute: 3)

    expect(names).to eq(%w[
      SEFR-TC06-01_HReq1.xml SEFR-TC06-01_EvReq1.xml
      SEFR-TC06-01_HRes1.xml SEFR-TC06-01_EvRes1.xml
      SEFR-TC06-01_HRes2.xml SEFR-TC06-01_EvRes2.xml
    ])
  end

  it 'numbers each country of a conversation on its own, and names the archive after the first exchange' do
    finland = exchange('FI', opened: 0)
    germany = exchange('DE', opened: 1)
    message(finland, 'request_sent', minute: 1)
    message(finland, 'response_received', minute: 2)
    message(germany, 'request_sent', minute: 3)
    message(germany, 'error_received', minute: 4)

    files = test_files(run: '02')

    expect(files.map(&:name)).to eq(%w[
      FRFI-TC06-02_HReq1.xml FRFI-TC06-02_EvReq1.xml FRFI-TC06-02_HRes1.xml FRFI-TC06-02_EvRes1.xml
      FRDE-TC06-02_HReq1.xml FRDE-TC06-02_EvReq1.xml FRDE-TC06-02_HRes1.xml FRDE-TC06-02_EvRes1.xml
    ])
    expect(files.archive_name).to eq('FRFI-TC06-02.zip')
  end

  it 'counts across two exchanges with the same country' do
    first = exchange('BE', opened: 0)
    second = exchange('BE', opened: 1)
    message(first, 'request_sent', minute: 1)
    message(first, 'response_received', minute: 2)
    message(second, 'request_sent', minute: 3)
    message(second, 'response_received', minute: 4)

    expect(names.last(4)).to eq(%w[
      FRBE-TC06-01_HReq2.xml FRBE-TC06-01_EvReq2.xml FRBE-TC06-01_HRes2.xml FRBE-TC06-01_EvRes2.xml
    ])
  end

  # A gateway connected to nobody talks to itself, and the journal then records
  # each message once sent and once received.
  it 'draws a message France sent itself once, from its sending' do
    france = exchange('FR')
    sent_request = message(france, 'request_sent', minute: 1)
    message(france, 'request_received', minute: 2)
    sent_response = message(france, 'response_sent', minute: 3)
    message(france, 'response_received', minute: 4)

    files = test_files

    expect(files.map(&:name)).to eq(%w[
      FRFR-TC06-01_HReq1.xml FRFR-TC06-01_EvReq1.xml FRFR-TC06-01_HRes1.xml FRFR-TC06-01_EvRes1.xml
    ])
    expect(files.map(&:content)).to eq([
      sent_request.ebms_header, sent_request.regrep_body, sent_response.ebms_header, sent_response.regrep_body,
    ])
  end

  it 'keeps its rank for a message with neither part recorded' do
    belgium = exchange('BE')
    message(belgium, 'request_sent', minute: 1, header: nil, body: nil)
    message(belgium, 'request_sent', minute: 2)

    expect(names).to eq(%w[FRBE-TC06-01_HReq2.xml FRBE-TC06-01_EvReq2.xml])
  end

  it 'numbers in the order the messages were recorded, across exchanges' do
    first = exchange('BE', opened: 0)
    second = exchange('BE', opened: 1)
    message(first, 'request_sent', minute: 1)
    message(second, 'request_sent', minute: 2)
    message(second, 'response_received', minute: 4)
    late = message(first, 'response_received', minute: 6)

    contents = test_files.to_h { [it.name, it.content] }

    expect(contents['FRBE-TC06-01_HRes2.xml']).to eq(late.ebms_header)
  end

  it 'names the archive after the first exchange that yields a file' do
    message(exchange('BE', opened: 0), 'message_unhandled', minute: 1)
    message(exchange('DE', opened: 1), 'request_sent', minute: 2)

    expect(test_files.archive_name).to eq('FRDE-TC06-01.zip')
  end

  # What a correspondent wrote is kept even when `R-EDM-REQ-C015` refused it.
  it 'leaves out an exchange whose country is not a code of the list' do
    forged = exchange('../x', incoming: true, opened: 0)
    belgium = exchange('BE', opened: 1)
    message(forged, 'request_received', minute: 1)
    message(forged, 'error_sent', minute: 2)
    message(belgium, 'request_sent', minute: 3)

    expect(names).to eq(%w[FRBE-TC06-01_HReq1.xml FRBE-TC06-01_EvReq1.xml])
  end

  # On the 1.2 line the request France receives from itself opens an exchange of
  # its own, so the two ends of the loop sit on two rows of the conversation.
  it 'draws a message France sent itself once when each end has its own exchange' do
    requesting = exchange('FR', opened: 0)
    providing = exchange('FR', incoming: true, opened: 1)
    sent_request = message(requesting, 'request_sent', minute: 1)
    message(providing, 'request_received', minute: 2)
    sent_error = message(providing, 'error_sent', minute: 3)
    message(requesting, 'error_received', minute: 4)

    files = test_files

    expect(files.map(&:name)).to eq(%w[
      FRFR-TC06-01_HReq1.xml FRFR-TC06-01_EvReq1.xml FRFR-TC06-01_HRes1.xml FRFR-TC06-01_EvRes1.xml
    ])
    expect(files.map(&:content)).to eq([
      sent_request.ebms_header, sent_request.regrep_body, sent_error.ebms_header, sent_error.regrep_body,
    ])
  end

  it 'leaves out an exchange whose correspondent is not known' do
    unknown = exchange(nil, incoming: true, opened: 0)
    belgium = exchange('BE', opened: 1)
    message(unknown, 'request_received', minute: 1)
    message(belgium, 'request_sent', minute: 2)

    expect(names).to eq(%w[FRBE-TC06-01_HReq1.xml FRBE-TC06-01_EvReq1.xml])
  end

  describe 'a conversation that yields nothing' do
    it 'yields nothing where no message kept a part' do
      message(exchange('BE'), 'request_sent', minute: 1, header: nil, body: nil)

      expect(test_files).to be_none
    end

    it 'yields nothing of an unhandled message' do
      message(exchange('BE'), 'message_unhandled', minute: 1)

      expect(test_files).to be_none
    end

    it 'yields nothing where the one exchange has no correspondent' do
      message(exchange(nil, incoming: true), 'request_received', minute: 1)

      expect(test_files).to be_none
    end
  end
end
