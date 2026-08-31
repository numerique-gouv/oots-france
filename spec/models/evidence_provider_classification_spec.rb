require 'rails_helper'

RSpec.describe EvidenceProviderClassification do
  subject(:concept) { described_class.new(**attributes) }

  let(:attributes) do
    {
      id: '5b8b7dbc-64e6-4b4b-9b40-fc0eb0e6a67b',
      type: 'codelist',
      scheme_id: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth',
      value_expression: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth',
      descriptions: { 'EN' => 'In which town were you born?' },
    }
  end

  it 'accepts what the rules of chapter 3.1.4 admit' do
    expect(concept.validate!(:announced_classification_concept)).to eq(concept)
  end

  # § 4.2.2 has the reissued query carry this identifier as its parameter, so
  # what is not one leaves nothing to ask the directory again with.
  it 'refuses an identifier that is not a UUID' do
    attributes[:id] = 'TownOfBirth'

    expect { concept.validate!(:announced_classification_concept) }
      .to raise_error(ConfigurationError, /L'identifiant doit être un UUID/)
  end

  # R-DSD-ERR-C005 carries an `i` flag, where the rules on Semantic Repository
  # identifiers do not: an upper-case UUID is admitted here and nowhere else.
  it 'admits an identifier written in upper case' do
    attributes[:id] = '5B8B7DBC-64E6-4B4B-9B40-FC0EB0E6A67B'

    expect(concept).to be_valid
  end

  it 'refuses a type the rules do not publish' do
    attributes[:type] = 'date'

    expect { concept.validate!(:announced_classification_concept) }
      .to raise_error(ConfigurationError, /doit valoir « string », « boolean » ou « codelist »/)
  end

  # R-DSD-ERR-C032: without the scheme, the code list the question draws its
  # answers from is unnamed.
  it 'refuses a code list published without its scheme' do
    attributes[:scheme_id] = nil

    expect { concept.validate!(:announced_classification_concept) }
      .to raise_error(ConfigurationError, /Le schéma de la liste de codes doit être rempli/)
  end

  # `[A-Z]{2}` and not `[A-Za-z]{2}`: the rule spells the country segment in
  # upper case, unlike the environment midfix beside it.
  it 'refuses a scheme whose country segment is lower case' do
    attributes[:scheme_id] = 'https://sr.acc.oots.tech.ec.europa.eu/codelists/fi/TownOfBirth'

    expect(concept).not_to be_valid
  end

  it 'admits the other two types without a scheme' do
    attributes.merge!(type: 'string', scheme_id: nil)

    expect(concept).to be_valid
  end

  # R-DSD-ERR-C033, wherever a scheme is published — the type does not exempt
  # it from being one the Semantic Repository could serve.
  it 'refuses a scheme outside the Semantic Repository' do
    attributes[:scheme_id] = 'https://example.org/codelists/FI/TownOfBirth'

    expect { concept.validate!(:announced_classification_concept) }
      .to raise_error(ConfigurationError, %r{codelists/PAYS/})
  end

  it 'admits the production scheme, which carries no environment midfix' do
    attributes[:scheme_id] = 'https://sr.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth'

    expect(concept).to be_valid
  end

  # R-DSD-ERR-C037: the expression is where the values live, and a code list
  # naming none leaves the user nothing to choose between.
  it 'refuses a code list that says nowhere where its values are' do
    attributes[:value_expression] = nil

    expect { concept.validate!(:announced_classification_concept) }
      .to raise_error(ConfigurationError, /L'expression des valeurs/)
  end

  # R-DSD-ERR-C038, which the rule itself compares lower-cased.
  it 'refuses an expression that is not an https URI' do
    attributes[:value_expression] = 'http://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth'

    expect { concept.validate!(:announced_classification_concept) }
      .to raise_error(ConfigurationError, %r{doit être une URI en « https:// »})
  end

  # The rule compares its own value lower-cased, so the scheme of the URI is
  # the one thing about it that is not case-sensitive.
  it 'admits an expression whose scheme is written in upper case' do
    attributes[:value_expression] = 'HTTPS://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth'

    expect(concept).to be_valid
  end

  # Both rules are written on `Type='codelist'` and on nothing else: a free
  # string or a boolean is answered by the user, not drawn from a published
  # list, so it has no expression to name.
  it 'asks no expression of the other two types' do
    attributes.merge!(type: 'boolean', scheme_id: nil, value_expression: nil)

    expect(concept).to be_valid
  end

  # R-DSD-ERR-C007 and C009: a question nobody can read is not one, and the
  # language is what a screen rendering it has to declare (RGAA 8.7).
  it 'refuses a question published in no language at all' do
    attributes[:descriptions] = {}

    expect(concept).not_to be_valid
  end

  it 'refuses a question whose language is not named' do
    attributes[:descriptions] = { nil => 'In which town were you born?' }

    expect(concept).not_to be_valid
  end

  # All the wordings or none: a concept half of whose questions can be shown
  # would be rendered in a language a screen cannot declare (RGAA 8.7).
  it 'refuses a set where a single wording does not name its language' do
    attributes[:descriptions] = { 'EN' => 'In which town were you born?', nil => 'Missä kaupungissa?' }

    expect(concept).not_to be_valid
  end

  # French where the directory published it, English otherwise — the choice
  # `Described` makes for every wording the directories publish.
  it 'asks the question in the reader’s language where the directory published one' do
    attributes[:descriptions] = { 'EN' => 'In which town were you born?', 'FR' => 'Dans quelle ville êtes-vous né ?' }

    expect(concept.label).to eq('Dans quelle ville êtes-vous né ?')
  end
end
