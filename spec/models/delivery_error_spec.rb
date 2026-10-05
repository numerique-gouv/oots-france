require 'rails_helper'

RSpec.describe DeliveryError do
  # The plugin names its enumeration where ebMS 3.0 Core writes the code.
  it 'reads the code in the form of the plugin and in the form of the norm alike' do
    expect([described_class.new(code: 'EBMS_0003').code, described_class.new(code: 'EBMS:0003').code])
      .to eq(%w[EBMS:0003 EBMS:0003])
  end

  it 'takes the four refusals of a configuration for what they are' do
    codes = %w[EBMS_0001 EBMS_0003 EBMS_0010 EBMS_0101]

    expect(codes.map { |code| described_class.new(code:) }).to all(be_configuration_refusal)
  end

  it 'leaves a connection failure to the verdict of the gateway' do
    expect(described_class.new(code: 'EBMS_0005')).not_to be_configuration_refusal
  end

  it 'leaves a policy it does not know of to that verdict too' do
    expect(described_class.new(code: 'EBMS_0103')).not_to be_configuration_refusal
  end

  it 'quotes the code and what the gateway said of it' do
    expect(described_class.new(code: 'EBMS_0003', detail: 'No matching party found').summary)
      .to eq('EBMS:0003 : No matching party found')
  end

  it 'quotes the code alone where the gateway said nothing more' do
    expect(described_class.new(code: 'EBMS_0003', detail: '').summary).to eq('EBMS:0003')
  end
end
