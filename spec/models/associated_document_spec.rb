require 'rails_helper'

RSpec.describe AssociatedDocument do
  # R-EDM-REQ-C119 (FATAL) closes the list, and the schema declares no type for
  # `sdg:AssociatedDocumentRequest`: nothing but this check keeps a value a
  # correspondent must refuse out of a request.
  describe '.vetted' do
    it 'lets through the three values the rule names' do
      expect(described_class.vetted(described_class::REQUESTABLE))
        .to eq(%w[Annex HumanReadableVersion Translation])
    end

    # The element is `0..n`: asking for nothing is what every request does
    # today.
    it 'accepts asking for nothing' do
      expect(described_class.vetted([])).to eq([])
    end

    it 'refuses a value the rule does not name, and says which one' do
      expect { described_class.vetted([described_class::ANNEX, 'Résumé']) }
        .to raise_error(ConfigurationError, /Résumé/)
    end

    # The rule compares whole strings, with no case folding.
    it 'refuses one of the three written in another case' do
      expect { described_class.vetted(%w[translation]) }
        .to raise_error(ConfigurationError, /translation/)
    end
  end
end
