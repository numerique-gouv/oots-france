require 'rails_helper'

RSpec.describe Requirement do
  # The console addresses its own pages by this segment: the whole identifier
  # names `sr.acc.oots…` in acceptance and `sr.oots…` in production, so a path
  # built from it would break on the way to production.
  it 'takes its short name from the last segment of the Semantic Repository URL' do
    expect(build(:requirement).uuid).to eq('00000000-0000-0000-0000-000000000000')
  end

  it 'has no short name when the directory published no identifier' do
    expect(build(:requirement, id: nil).uuid).to be_nil
  end

  # A request writes this identifier into its `Requirements` slot, where
  # R-EDM-REQ-C008 bounds its shape. The catalogue the console lists is not
  # obliged to honour it, hence a validation asked for rather than applied on
  # reading.
  describe 'what a message may carry' do
    it 'accepts what the directory publishes, acceptance midfix included' do
      accepted = build(:requirement,
        id: 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000')

      expect(accepted.validate!(:announced_requirement)).to be_a(described_class)
    end

    it 'refuses an identifier that is not a Semantic Repository URL' do
      expect { build(:requirement, id: 'https://sr/requirements/1').validate!(:announced_requirement) }
        .to raise_error(ConfigurationError, /L'identifiant/)
    end

    it 'refuses an identifier the directory published empty' do
      expect { build(:requirement, id: nil).validate!(:announced_requirement) }
        .to raise_error(ConfigurationError, /L'identifiant/)
    end

    # R-EDM-REQ-C010 and C094 make `lang` mandatory on both wordings, and a
    # directory that published one without it leaves the language nil.
    it 'refuses a wording the directory published without naming its language' do
      [{ descriptions: { nil => 'Test Requirement' } }, { details: { nil => 'What it proves' } }].each do |published|
        expect { build(:requirement, **published).validate!(:announced_requirement) }
          .to raise_error(ConfigurationError, /une formulation ne nomme pas sa langue/)
      end
    end

    # R-EDM-REQ-C008 carries no `i` flag, unlike the R-EDM-REQ-C026 that bounds
    # the identifier of a data service.
    it 'refuses an upper-case UUID, that rule being case-sensitive' do
      published = 'https://sr.oots.tech.ec.europa.eu/requirements/F8A6A284-34E9-42C7-9733-63B5C4F4AA42'

      expect { build(:requirement, id: published).validate!(:announced_requirement) }
        .to raise_error(ConfigurationError, /L'identifiant/)
    end
  end

  it 'answers the procedures and the countries declaring it' do
    requirement = build(:requirement, reference_frameworks: [
      build(:reference_framework, procedure_code: '00', country: 'FR'),
      build(:reference_framework, procedure_code: 'R1', country: 'DE'),
      build(:reference_framework, procedure_code: 'R1', country: 'BE'),
    ])

    expect(requirement.procedure_codes).to eq(%w[00 R1])
    expect(requirement.countries).to eq(%w[FR DE BE])
  end

  it 'leaves out a code or a country the directory published empty' do
    requirement = build(:requirement, reference_frameworks: [
      build(:reference_framework, procedure_code: '', country: ''),
      build(:reference_framework, procedure_code: 'R1', country: 'DE'),
    ])

    expect(requirement.procedure_codes).to eq(['R1'])
    expect(requirement.countries).to eq(['DE'])
  end

  # French where the directory publishes it, English otherwise — which every
  # entry of the catalogue carries. Inverting the two would name most of the
  # console in a language nobody asked for.
  it 'prefers the French name to the English one' do
    published = { 'EN' => 'Test Requirement', 'FR' => 'Exigence de test' }

    expect(build(:requirement, descriptions: published).label).to eq('Exigence de test')
    expect(build(:requirement, descriptions: published.except('FR')).label).to eq('Test Requirement')
    expect(build(:requirement, descriptions: { 'FI' => 'Testivaatimus' }).label).to eq('Testivaatimus')
  end

  # The directory nests declarations inside the requirement; a listing of
  # procedures walks the graph the other way.
  it 'names itself on each declaration it carries' do
    requirement = build(:requirement)

    expect(requirement.reference_frameworks.first.requirement).to be(requirement)
  end
end
