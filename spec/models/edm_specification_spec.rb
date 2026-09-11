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

    # The fallback of `resolve` is the rule chapter 4.7 §2.6.2 gives a received
    # message; a column is not a message, and an exchange whose version was
    # never settled must not read as one conducted in the preferred version.
    it 'leaves an exchange that names no version without one' do
      exchange = create(:exchange, :unsettled_line)

      expect(exchange.specification).to be_nil
      expect(exchange.reload.specification).to be_nil
      expect(exchange.read_attribute_before_type_cast(:specification)).to be_nil
    end

    it 'reads an empty column as no version rather than as the preferred one' do
      expect(described_class.new.cast('')).to be_nil
    end

    # A version France does not speak has no business in this column, and
    # nothing writes one: read back as nothing, rather than silently as 2.0.
    it 'reads a version France does not speak as no version' do
      expect(described_class.new.cast('oots-edm:v1.0')).to be_nil
    end

    it 'writes nothing where there is no version to write' do
      expect(described_class.new.serialize(nil)).to be_nil
    end
  end
end
