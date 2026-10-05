require 'rails_helper'

RSpec.describe MessageErrorsParser do
  subject(:parser) { described_class.new(built_envelope('domibus/erreursRemise')) }

  it 'reads one error per attempt the gateway recorded' do
    expect(parser.errors.map(&:code)).to contain_exactly('EBMS:0003', 'EBMS:0005')
  end

  # The schema promises no order, and the fixture lists the last attempt first.
  it 'takes the last attempt by the instant the gateway recorded' do
    expect(parser.latest).to have_attributes(code: 'EBMS:0003', detail: 'No matching party found',
      timestamp: Time.iso8601('2026-10-05T10:03:00Z'))
  end

  it 'has no last attempt where the gateway recorded none' do
    expect(described_class.new(built_envelope('domibus/erreursRemise.vide')).latest).to be_nil
  end

  # In the end-to-end loop the same identifier names both sides of one gateway.
  it 'leaves out what the gateway recorded as the receiving side' do
    envelope = built_envelope('domibus/erreursRemise').sub('<mshRole>SENDING</mshRole><timestamp>2026-10-05T10:03',
      '<mshRole>RECEIVING</mshRole><timestamp>2026-10-05T10:03')

    expect(described_class.new(envelope).latest.code).to eq('EBMS:0005')
  end

  it 'refuses a body that is not the answer to this operation' do
    expect { described_class.new(real_envelope('soumissionMessage')) }.to raise_error(UnreadableMessageError)
  end
end
