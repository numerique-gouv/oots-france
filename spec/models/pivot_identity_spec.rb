require 'rails_helper'

RSpec.describe PivotIdentity do
  def certified(**overrides)
    Demo::UserIdentity.new(given_name: 'Jacques', family_name: 'Martin', birthdate: '2004-01-01', gender: 'male',
      place_of_birth: '75102', **overrides)
  end

  def identity(**) = described_class.from_france_connect(certified(**))

  it 'reads the query of CA1 off the identity FranceConnect+ certified' do
    expect(identity.to_query('13002526500013')).to eq(
      nomNaissance: 'Martin', 'prenoms[]': 'Jacques', anneeDateNaissance: '2004', moisDateNaissance: '01',
      jourDateNaissance: '01', sexeEtatCivil: 'M', codeCogInseeCommuneNaissance: '75102', recipient: '13002526500013',
    )
  end

  # CA2: the endpoint takes one given name.
  it 'keeps the first of the given names' do
    expect(identity(given_name: 'Jean  Pierre').given_name).to eq('Jean')
  end

  it 'reads the sex FranceConnect+ publishes' do
    expect([identity.sex, identity(gender: 'female').sex]).to eq(%w[M F])
  end

  # RG15: neither man nor woman, and nobody is asked for.
  it 'is none where FranceConnect+ says neither sex' do
    expect([nil, '', 'other'].map { |gender| identity(gender:) }).to all(be_nil)
  end

  it 'takes a code of the Code officiel géographique, Corsica included' do
    expect(%w[75102 2A004 2B033].map { |place| identity(place_of_birth: place).birth_commune })
      .to eq(%w[75102 2A004 2B033])
  end

  # « Ne pas remplir si la personne est née à l'étranger »: the empty birthplace
  # FranceConnect+ publishes then, and the `99` series that names a country.
  it 'sends no place for a person born abroad' do
    ['', nil, '99134', 'Aarhus'].each do |place|
      expect(identity(place_of_birth: place).to_query('13002526500013')).not_to have_key(:codeCogInseeCommuneNaissance)
    end
  end

  describe '.from_request' do
    def person(**overrides)
      NaturalPerson.new(level_of_assurance: 'High', family_name: 'Martin', given_name: 'Jacques',
        date_of_birth: '2004-01-01', place_of_birth: '75102', gender: 'Male', **overrides)
    end

    it 'reads the query of CA1 off a request that holds it whole' do
      expect(described_class.from_request(person).to_query('13002526500013'))
        .to eq(identity.to_query('13002526500013'))
    end

    it 'reads the sex in both profiles of the code list' do
      expect(%w[Male 1 Female 2].map { |gender| described_class.from_request(person(gender:)).sex })
        .to eq(%w[M M F F])
    end

    # RG14: neither the sex nor the commune by its code, and the match waits
    # for the identification — a name is never resolved.
    it 'is none where the request lacks the sex or a commune by its code' do
      lacking = [{ gender: nil }, { gender: 'Unspecified' }, { gender: '0' }, { place_of_birth: nil },
                 { place_of_birth: 'Nanterre' }, { place_of_birth: 'Aarhus' }, { place_of_birth: '99134' }]

      expect(lacking.map { |overrides| described_class.from_request(person(**overrides)) }).to all(be_nil)
    end
  end
end
