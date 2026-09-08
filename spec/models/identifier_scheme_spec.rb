require 'rails_helper'

# `R-EDM-REQ-C012` and the six rules that repeat it word for word, which
# `IdentifierScheme.agent_scheme?` names. What France accepts on the way in it
# echoes on the way out, so a reading looser or tighter than the assertion
# breaks the answer as well as the request.
RSpec.describe IdentifierScheme do
  describe '.agent_scheme?' do
    it 'accepts the French SIRET scheme this deployment declares itself under' do
      expect(described_class).to be_agent_scheme(described_class::FRENCH)
    end

    it 'accepts the unregistered fallback the intermediary platform uses' do
      expect(described_class).to be_agent_scheme(described_class::FRENCH_FALLBACK)
    end

    it 'accepts any EAS code the list publishes' do
      expect(described_class).to be_agent_scheme('urn:cef.eu:names:identifier:EAS:9930')
    end

    it 'refuses an EAS code the list does not publish' do
      expect(described_class).not_to be_agent_scheme('urn:cef.eu:names:identifier:EAS:9999')
    end

    it 'refuses a scheme carrying neither prefix' do
      expect(described_class).not_to be_agent_scheme('SIRET')
    end

    it 'refuses a prefix followed by nothing' do
      expect(described_class).not_to be_agent_scheme(described_class::EAS_PREFIX)
    end

    it 'refuses a nil scheme' do
      expect(described_class).not_to be_agent_scheme(nil)
    end

    # The second branch reads `OOTS_Country-CodeList`, the countries taking part
    # in OOTS — a far shorter list than the `CountryIdentificationCode` that
    # `R-EDM-REQ-C015` compares an address to. Confusing the two would accept a
    # scheme the rule refuses.
    it 'accepts an unregistered scheme naming an OOTS country' do
      expect(described_class).to be_agent_scheme('urn:oasis:names:tc:ebcore:partyid-type:unregistered:DE')
    end

    it 'refuses an unregistered scheme naming a country outside OOTS' do
      expect(described_class).not_to be_agent_scheme('urn:oasis:names:tc:ebcore:partyid-type:unregistered:JP')
    end

    # « For testing purposes the code "oots" can be used », a third alternative
    # the assertion carries and the prose's two prefixes do not spell out.
    it 'accepts the literal `oots` beside the country codes' do
      expect(described_class).to be_agent_scheme('urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots')
    end

    # The assertion reads `substring-after`, which finds the prefix wherever it
    # sits: anchoring at the head would refuse what the rule accepts, and what
    # is accepted here is echoed into an answer the same assertion then judges.
    it 'accepts a scheme whose prefix is preceded by anything, as substring-after does' do
      expect(described_class).to be_agent_scheme("xx#{described_class::FRENCH}")
    end

    it 'refuses a scheme whose code is followed by anything' do
      expect(described_class).not_to be_agent_scheme("#{described_class::FRENCH}0")
    end
  end

  # The lists as the TDD publish them. Pinned by size so that a code lost to a
  # careless edit is caught here rather than by a correspondent being refused.
  it 'carries the EAS list whole' do
    expect(described_class::EAS_CODES.size).to eq(98)
  end

  # Thirty-one countries, and the `oots` of the rule beside them.
  it 'carries the OOTS country list, plus the testing code' do
    expect(described_class::UNREGISTERED_CODES.size).to eq(32)
  end
end
