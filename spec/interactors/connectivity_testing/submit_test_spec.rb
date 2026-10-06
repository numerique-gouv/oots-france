require 'rails_helper'

RSpec.describe ConnectivityTesting::SubmitTest do
  subject(:submit) { described_class.call(test:, gateway:) }

  let(:test) { create(:connectivity_test) }
  let(:gateway) { gateway_accepting_submissions(message_id: 'test@domibus.eu') }

  it 'hands the gateway a test message towards the party' do
    submit

    expect(gateway).to have_received(:submit).with(include('AP_EL_').and(include('200704/test')))
  end

  it 'keeps the identifier the gateway gave the message' do
    submit

    expect(test.reload).to have_attributes(message_id: 'test@domibus.eu', outcome: 'pending')
  end

  context 'when the gateway refuses the submission' do
    let(:gateway) { instance_double(DomibusClient) }

    before do
      allow(gateway).to receive(:submit)
        .and_raise(Faraday::ServerError.new('500', { status: 500, body: built_envelope('domibus/soumissionRefusee') }))
    end

    it 'settles the test as not submitted, with the code and the message of the fault' do
      submit

      expect(test.reload).to have_attributes(outcome: 'not_submitted', error_code: 'EBMS:0003',
        error_detail: start_with('ValueInconsistent detail: Receiver party could not be found'),
        submission_refusal: nil, message_id: nil)
    end
  end

  context 'when the gateway cannot be reached' do
    let(:gateway) { instance_double(DomibusClient) }

    before { allow(gateway).to receive(:submit).and_raise(Faraday::ConnectionFailed, 'Connection refused') }

    it 'settles the test as not submitted, with the error' do
      submit

      expect(test.reload).to have_attributes(outcome: 'not_submitted', submission_refusal: 'Connection refused')
    end
  end

  context 'when the gateway refuses with a fault naming no code' do
    let(:gateway) { instance_double(DomibusClient) }

    before do
      fault = built_envelope('domibus/soumissionRefusee').sub(%r{<soap:Detail>.*</soap:Detail>}, '')
      allow(gateway).to receive(:submit).and_raise(Faraday::ServerError.new('500', { status: 500, body: fault }))
    end

    it 'keeps the words of the fault' do
      submit

      expect(test.reload).to have_attributes(outcome: 'not_submitted', error_code: nil,
        submission_refusal: 'Message submission failed')
    end
  end

  context 'when the gateway answers something unreadable' do
    let(:gateway) { instance_double(DomibusClient) }

    before { allow(gateway).to receive(:submit).and_raise(UnreadableMessageError, 'illisible') }

    it 'settles the test as not submitted, with what could not be read' do
      submit

      expect(test.reload).to have_attributes(outcome: 'not_submitted', submission_refusal: 'illisible')
    end
  end

  context 'when the gateway gives the message no identifier' do
    let(:gateway) { gateway_accepting_submissions(message_id: '') }

    it 'settles the test as not submitted, and says so' do
      submit

      expect(test.reload).to have_attributes(outcome: 'not_submitted',
        submission_refusal: I18n.t('interactors.connectivity_testing.submit_test.no_identifier'))
    end
  end

  it 'submits nothing for a test already submitted' do
    test.update!(message_id: 'deja@domibus.eu')

    submit

    expect(gateway).not_to have_received(:submit)
  end

  # RG7 of OOTS-252: a connectivity test is not an exchange.
  it 'writes neither an exchange nor a line of the exchange log' do
    expect { submit }.not_to(change { [Exchange.count, AuditEvent.count] })
  end
end
