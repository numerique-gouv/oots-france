require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#abbreviated_identifier' do
    it 'keeps the tail, which is what one compares between two rows' do
      expect(helper.abbreviated_identifier('e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b01')).to eq('…3a1b01')
    end

    # An event may name no exchange at all — a refusal pronounced before one was
    # opened — and the callers should not each have to remember it.
    it 'says nothing of a value there is none of' do
      expect(helper.abbreviated_identifier(nil)).to eq('…')
    end

    it 'leaves alone what is already shorter than the tail' do
      expect(helper.abbreviated_identifier('ab')).to eq('…ab')
    end
  end
end
