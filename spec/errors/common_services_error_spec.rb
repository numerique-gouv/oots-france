require 'rails_helper'

RSpec.describe CommonServicesError do
  # The distinction the whole console rests on: a directory that answered the
  # question, and one that never answered at all.
  describe 'an outage against a refusal' do
    it 'is an outage when the service named no code' do
      expect(described_class.new('la signature ne se vérifie pas')).to be_outage
    end

    it 'is a refusal when the service named one' do
      expect(described_class.new('rien de publié', code: 'DSD:ERR:0001')).not_to be_outage
    end
  end

  # Chapter 3.2.4 for the Evidence Broker, chapter 3.1.4 for the Data Service
  # Directory: a directory with nothing to give refuses rather than answering
  # empty, and reserves one code for saying so.
  describe 'what « nobody publishes this here » is' do
    it 'is the Evidence Broker saying it issues no such type' do
      expect(described_class.new('rien', code: 'EB:ERR:0001')).to be_nothing_published
    end

    it 'is the Data Service Directory saying it knows no such provider' do
      expect(described_class.new('rien', code: 'DSD:ERR:0001')).to be_nothing_published
    end

    it 'is not a directory refusing the question itself' do
      expect(described_class.new('paramètre absent', code: 'DSD:ERR:0003')).not_to be_nothing_published
    end

    it 'is not an outage, which settles nothing about what is published' do
      expect(described_class.new('injoignable')).not_to be_nothing_published
    end
  end
end
