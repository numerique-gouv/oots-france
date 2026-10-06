require 'rails_helper'

RSpec.describe SoapFaultParser do
  let(:refusal) { built_envelope('domibus/soumissionRefusee') }

  it 'reads the code and the message the plugin gives its refusal' do
    fault = described_class.new(refusal)

    expect(fault.code).to eq('EBMS:0003')
    expect(fault.message).to start_with('ValueInconsistent detail: Receiver party could not be found')
  end

  it 'writes an ebMS code in the norm\'s form, and keeps one of the plugin as it comes' do
    expect(described_class.new(refusal.sub('EBMS:0003', 'EBMS_0010')).code).to eq('EBMS:0010')
    expect(described_class.new(refusal.sub('EBMS:0003', 'WS_PLUGIN_0005')).code).to eq('WS_PLUGIN_0005')
  end

  it 'falls back on the reason of a fault that carries no detail' do
    fault = described_class.new(refusal.sub(%r{<soap:Detail>.*</soap:Detail>}, ''))

    expect(fault).to have_attributes(code: nil, reason: 'Message submission failed')
  end

  it 'says nothing of a body that is no fault' do
    expect(described_class.new('Bad Gateway')).to have_attributes(code: nil, reason: nil)
    expect(described_class.new(nil)).to have_attributes(code: nil, reason: nil)
  end
end
