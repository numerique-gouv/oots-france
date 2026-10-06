require 'rails_helper'

RSpec.describe MessageStatusParser do
  def parsed(name) = described_class.new(built_envelope("domibus/#{name}"))

  it 'reads an acknowledgement, with or without a warning' do
    expect(parsed('statutAcquitte')).to be_acknowledged
    expect(parsed('statutAcquitteAvecAvertissement')).to be_acknowledged
  end

  it 'reads the gateway giving up' do
    expect(parsed('statutEchec')).to have_attributes(failed?: true, acknowledged?: false)
  end

  it 'reads a message the gateway does not know' do
    expect(parsed('statutInconnu')).to be_not_found
  end

  it 'reads a status still on its way as none of the three' do
    expect(parsed('statutEnFile')).to have_attributes(status: 'SEND_ENQUEUED', acknowledged?: false, failed?: false,
      not_found?: false)
  end

  it 'refuses an answer carrying no status' do
    expect { described_class.new('<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"/>') }
      .to raise_error(UnreadableMessageError)
  end
end
