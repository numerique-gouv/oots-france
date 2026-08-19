require 'rails_helper'

RSpec.describe DataService do
  # A request adopts most of it (chapter 4.5.1), so what a foreign directory
  # publishes has to satisfy the rules bounding those slots before it reaches
  # one. The console, which only lists, validates nothing.
  describe 'what a message may carry' do
    it 'accepts what the acceptance directory publishes' do
      expect(build(:data_service).validate!(:announced_data_service)).to be_a(described_class)
    end

    # R-EDM-REQ-C026: the identifier the directory assigns to the pairing.
    it 'refuses an identifier that is not a UUID' do
      expect { build(:data_service, id: 'service-de-test').validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /L'identifiant/)
    end

    it 'refuses an identifier the directory published empty' do
      expect { build(:data_service, id: nil).validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /L'identifiant/)
    end

    # R-EDM-REQ-C027: a Semantic Repository URL, whose country segment is a
    # code of the OOTS country list, or the lower-case `oots`.
    it 'refuses a classification that is not a Semantic Repository URL' do
      expect { build(:data_service, evidence_type_classification: 'FI/x').validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /Le type de justificatif/)
    end

    it 'refuses a classification the directory published empty' do
      expect { build(:data_service, evidence_type_classification: nil).validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /Le type de justificatif/)
    end

    it 'accepts a country code, in production as in acceptance, and the agreed oots' do
      [
        'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
        'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/19f0783e-7cdc-4146-9ff9-e331514ffb74',
        'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000',
      ].each do |published|
        accepted = build(:data_service, evidence_type_classification: published)

        expect(accepted.validate!(:announced_data_service)).to be_a(described_class)
      end
    end

    # The two rules do not agree on the case of the UUID, and the difference is
    # deliberate: R-EDM-REQ-C026 carries the `i` flag where C027 does not.
    it 'accepts an upper-case identifier, which its own rule matches case-insensitively' do
      accepted = build(:data_service, id: '41170824-15D9-4C16-984E-63B75B937B8C')

      expect(accepted.validate!(:announced_data_service)).to be_a(described_class)
    end

    it 'refuses an upper-case UUID in the classification, whose rule is case-sensitive' do
      published = 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/CA8AFED6-2DC0-422A-A931-D21C3D8D370E'

      expect { build(:data_service, evidence_type_classification: published).validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /Le type de justificatif/)
    end

    # That rule carries no `i` flag: the country segment is upper-case, and only
    # the `oots` of the agreed data models is lower-case.
    it 'refuses a country segment of the wrong case or the wrong length' do
      %w[fr OOTS FRAN F].each do |segment|
        published = "https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/#{segment}/" \
                    'ca8afed6-2dc0-422a-a931-d21c3d8d370e'

        expect { build(:data_service, evidence_type_classification: published).validate!(:announced_data_service) }
          .to raise_error(ConfigurationError, /Le type de justificatif/)
      end
    end

    # R-EDM-REQ-C032 makes `DistributedAs` mandatory, and a distribution with
    # no format says nothing about how the evidence comes back.
    it 'refuses a distribution with no format' do
      expect { build(:data_service, distribution_format: nil).validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /Le format de distribution/)
    end

    # R-EDM-REQ-C029 and C031 make `lang` mandatory on both wordings, and a
    # directory that published one without it leaves the language nil.
    it 'refuses a wording the directory published without naming its language' do
      [{ descriptions: { nil => 'Dummy PDF' } }, { details: { nil => 'A description' } }].each do |published|
        expect { build(:data_service, **published).validate!(:announced_data_service) }
          .to raise_error(ConfigurationError, /une formulation ne nomme pas sa langue/)
      end
    end

    # Chapter 4.5.1 leaves the language optional: absent, the evidence comes
    # back in any of the available ones.
    it 'accepts a service the directory published no language for' do
      expect(build(:data_service, distribution_language: nil).validate!(:announced_data_service))
        .to be_a(described_class)
    end

    # R-EDM-REQ-C118: a code of the `LanguageCode` list, all of two upper-case
    # letters — never a locale, never a lower-case code.
    it 'refuses a language that is not a code of the list' do
      %w[en en-GB ENG].each do |published|
        expect { build(:data_service, distribution_language: published).validate!(:announced_data_service) }
          .to raise_error(ConfigurationError, /La langue de distribution/)
      end
    end
  end

  it 'prefers the French name to the English one' do
    published = { 'EN' => 'Dummy PDF', 'FR' => 'PDF de test' }

    expect(build(:data_service, descriptions: published).label).to eq('PDF de test')
  end
end
