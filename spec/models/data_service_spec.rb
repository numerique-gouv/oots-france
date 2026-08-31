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

    # R-DSD-RESP-C010: the data model the directory publishes is a Semantic
    # Repository URL under `datamodels/`, with or without an environment midfix.
    it 'accepts the data model URL the directory publishes, in production as in acceptance' do
      [
        'https://sr.oots.tech.ec.europa.eu/datamodels/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40',
        'https://sr.acc.oots.tech.ec.europa.eu/datamodels/SDG-CertificateOfBirth',
      ].each do |published|
        accepted = build(:data_service, distribution_conforms_to: published)

        expect(accepted.validate!(:announced_data_service)).to be_a(described_class)
      end
    end

    # The v1.0 prefix, which R-EDM-REQ-C034 still tolerates on a request and
    # R-DSD-RESP-C010 no longer lets a directory publish: the value is validated
    # on the rule governing where it comes from, the narrower of the two.
    it 'refuses the v1.0 prefix the directory may no longer publish' do
      published = 'https://sr.oots.tech.ec.europa.eu/distributions/1c9a2e1e-1f1a-4b0e-9c2b-2f5e6a3d7c40'

      expect { build(:data_service, distribution_conforms_to: published).validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /Le modèle de données/)
    end

    it 'refuses a data model that is not a Semantic Repository URL at all' do
      published = 'SDG-CertificateOfBirth'

      expect { build(:data_service, distribution_conforms_to: published).validate!(:announced_data_service) }
        .to raise_error(ConfigurationError, /Le modèle de données/)
    end

    # Optional twice over: R-DSD-RESP-C039 only makes it mandatory on a
    # structured distribution, and R-DSD-RESP-C067 forbids it on the others.
    it 'accepts a service the directory published no data model for' do
      expect(build(:data_service, distribution_conforms_to: nil).validate!(:announced_data_service))
        .to be_a(described_class)
    end
  end

  # Which side of R-EDM-REQ-C107 the requested format falls on, and so whether
  # the request may name a data model beside it.
  describe '#structured_distribution?' do
    it 'is true of the two media types the code list marks structured' do
      %w[application/xml application/json].each do |format|
        expect(build(:data_service, distribution_format: format)).to be_structured_distribution
      end
    end

    # The four R-EDM-REQ-C107 names, and then a format the list does not carry:
    # the rule is fatal in one direction only, so an unknown format is treated
    # as the one where writing nothing is safe.
    it 'is false of the unstructured ones, and of a format the list does not carry' do
      %w[application/pdf image/jpeg image/png image/svg+xml application/zip].each do |format|
        expect(build(:data_service, distribution_format: format)).not_to be_structured_distribution
      end
    end
  end

  # Whether an absent data model is the directory at fault or the rules
  # excusing it: C039 and C041 require the value beside a structured format,
  # unless the record publishes an unstructured distribution as well.
  describe '#data_model_required?' do
    it 'is true of a structured distribution published on its own' do
      expect(build(:data_service, distribution_format: 'application/xml')).to be_data_model_required
    end

    it 'is false where an unstructured distribution is published beside it' do
      published = build(:data_service, distribution_format: 'application/json',
        unstructured_sibling_published: true)

      expect(published).not_to be_data_model_required
    end

    # C067 forbids the value beside an unstructured format rather than asking
    # for it, so nothing is owed there whatever else the record publishes.
    it 'is false of an unstructured distribution' do
      expect(build(:data_service, distribution_format: EvidenceType::PDF)).not_to be_data_model_required
    end
  end

  # The console names the rule it invokes, and the two are one sentence under
  # two identifiers: C039 judges an XML distribution, C041 a JSON one.
  it 'names the rule that requires the data model of the format read' do
    expect(build(:data_service, distribution_format: 'application/xml').data_model_rule)
      .to eq('R-DSD-RESP-C039')
    expect(build(:data_service, distribution_format: 'application/json').data_model_rule)
      .to eq('R-DSD-RESP-C041')
    expect(build(:data_service, distribution_format: EvidenceType::PDF).data_model_rule).to be_nil
  end

  # Only a directory answer can say what the record published; every other way
  # of building a service starts from a distribution it already holds and knows
  # of no second one, so both defaults claim nothing.
  it 'counts a service built without a word on it as distributed, and alone' do
    expect(build(:data_service)).to have_attributes(distribution_published: true,
      unstructured_sibling_published: false)
  end

  it 'prefers the French name to the English one' do
    published = { 'EN' => 'Dummy PDF', 'FR' => 'PDF de test' }

    expect(build(:data_service, descriptions: published).label).to eq('PDF de test')
  end
end
