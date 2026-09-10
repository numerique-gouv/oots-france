require 'rails_helper'

RSpec.describe EdmSpecification do
  describe '.resolve' do
    it 'answers the version a message announces when France speaks it' do
      expect(described_class.resolve('oots-edm:v1.2')).to eq(described_class::V1_2)
    end

    # Chapter 4.7 §2.6.2 has a receiver pick its rule set from what the message
    # announces. A version France cannot read leaves nothing to pick, and the
    # 2.0 rules are what then refuse the message and word the refusal.
    it 'falls back on the preferred version for one France does not speak' do
      expect(described_class.resolve('oots-edm:v1.0')).to eq(described_class::V2_0)
      expect(described_class.resolve(nil)).to eq(described_class::V2_0)
    end
  end

  describe 'what separates the two lines' do
    it 'carries the version and the exchange in the header of a 2.0 message alone' do
      expect(described_class::V2_0).to be_announced_in_header
      expect(described_class::V2_0).to be_exchange_named_in_header

      expect(described_class::V1_2).not_to be_announced_in_header
      expect(described_class::V1_2).not_to be_exchange_named_in_header
    end

    it 'translates the procedure slot and reduces the distribution in 1.2 alone' do
      expect(described_class::V1_2).to be_translated_procedure
      expect(described_class::V1_2).not_to be_extended_distribution

      expect(described_class::V2_0).not_to be_translated_procedure
      expect(described_class::V2_0).to be_extended_distribution
    end

    it 'packages the objects of a response in 2.0 alone' do
      expect(described_class::V2_0).to be_packaged_response
      expect(described_class::V1_2).not_to be_packaged_response
    end
  end

  # The column stores the identifier the messages carry; every builder and
  # parser serving an exchange asks it the object.
  describe described_class::Type do
    it 'reads an exchange back as the version object, whichever form was written' do
      exchange = create(:exchange, specification: EdmSpecification::V1_2)

      expect(exchange.reload.specification).to eq(EdmSpecification::V1_2)
      expect(exchange.read_attribute_before_type_cast(:specification)).to eq('oots-edm:v1.2')
    end

    it 'accepts the identifier as well as the object' do
      exchange = create(:exchange, specification: 'oots-edm:v1.2')

      expect(exchange.reload.specification).to eq(EdmSpecification::V1_2)
    end

    it 'gives an exchange that names none the preferred version' do
      expect(build(:exchange).specification).to eq(EdmSpecification.preferred)
    end
  end
end
