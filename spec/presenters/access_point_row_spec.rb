require 'rails_helper'

RSpec.describe AccessPointRow do
  let(:parties) do
    %w[AP_FR_01 AP_EL_01].map do |name|
      PmodeParty.new(name:, identifier: name, identifier_type: "urn:oasis:names:tc:ebcore:partyid-type:unregistered:#{name[3, 2]}",
        endpoint: 'https://msh')
    end
  end

  def party(name, country = name[3, 2])
    PmodeParty.new(name:, identifier: name, identifier_type: "urn:oasis:names:tc:ebcore:partyid-type:unregistered:#{country}",
      endpoint: 'https://msh')
  end

  def names(parties, tests, countries)
    described_class.all(parties:, tests:, countries:, certificates: []).map(&:name)
  end

  it 'lists the connected parties first, then the other declared parties, then the tests of parties no longer declared' do
    tests = [
      build(:connectivity_test, :acknowledged, party_name: 'AP_ZZ_01',
        party_identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:ZZ'),
      build(:connectivity_test, :acknowledged, party_name: 'AP_FR_01'),
    ]

    rows = described_class.all(parties: [party('AP_EL_01'), party('AP_FR_01')], tests:,
      countries: { 'FR' => 'France', 'EL' => 'Grèce' }, certificates: [])

    expect(rows.map { |row| [row.name, row.declared?] })
      .to eq([['AP_FR_01', true], ['AP_EL_01', true], ['AP_ZZ_01', false]])
    expect(rows.map(&:country_code)).to eq(%w[FR EL] + [nil])
  end

  it 'orders a group by the name of the country, then by the name of the party' do
    parties = [party('SDG-OOP-AT-SCONAP-Q', 'AT'), party('AP_BE_01'), party('AP_AT_01')]

    expect(names(parties, [], { 'AT' => 'Autriche', 'BE' => 'Belgique' }))
      .to eq(%w[AP_AT_01 SDG-OOP-AT-SCONAP-Q AP_BE_01])
  end

  it 'puts the parties without a country at the end of their group' do
    parties = [party('ec_support_acc', 'oots'), party('AP_SE_01'), party('AP_AT_01')]
    tests = [build(:connectivity_test, :acknowledged, party_name: 'AP_SE_01')]

    expect(names(parties, tests, { 'AT' => 'Autriche', 'SE' => 'Suède' })).to eq(%w[AP_SE_01 AP_AT_01 ec_support_acc])
  end

  it 'leaves a party no longer declared at the bottom, even connected' do
    tests = [build(:connectivity_test, :acknowledged, party_name: 'AP_ZZ_01',
      party_identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:ZZ')]

    expect(names([party('AP_FR_01'), party('ec_support_acc', 'oots')], tests, { 'FR' => 'France', 'ZZ' => 'Zédie' }))
      .to eq(%w[AP_FR_01 ec_support_acc AP_ZZ_01])
  end

  it 'orders the parties no longer declared like the others, by country, the ones without a country last' do
    tests = [
      build(:connectivity_test, :acknowledged, party_name: 'ec_old', party_identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots'),
      build(:connectivity_test, :acknowledged, party_name: 'AP_ZZ_01', party_identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:ZZ'),
      build(:connectivity_test, :acknowledged, party_name: 'AP_BE_01', party_identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:BE'),
    ]

    expect(names([party('AP_FR_01')], tests, { 'BE' => 'Belgique', 'FR' => 'France', 'ZZ' => 'Zédie' }))
      .to eq(%w[AP_FR_01 AP_BE_01 AP_ZZ_01 ec_old])
  end

  it 'offers a test towards a declared party whose last test is settled' do
    rows = described_class.all(parties:, tests: [build(:connectivity_test, :acknowledged, party_name: 'AP_EL_01')],
      countries: {}, certificates: [])

    expect(rows.map(&:testable?)).to eq([true, true])
    expect(rows.map(&:outcome)).to eq(%w[acknowledged never_tested])
  end

  it 'offers none towards a pending test, nor towards a party no longer declared' do
    tests = [build(:connectivity_test, party_name: 'AP_EL_01'), build(:connectivity_test, :acknowledged, party_name: 'AP_ZZ_01')]

    rows = described_class.all(parties:, tests:, countries: {}, certificates: [])

    expect(rows.to_h { |row| [row.name, row.testable?] }).to eq('AP_FR_01' => true, 'AP_EL_01' => false, 'AP_ZZ_01' => false)
  end

  it 'finds the certificate of a party whatever the case of its alias' do
    party = PmodeParty.new(name: 'AP_NL_01', identifier: '00000001805544434000',
      identifier_type: 'urn:cef.eu:names:identifier:EAS:0190', endpoint: 'https://msh')
    certificates = [TruststoreEntry.new(name: 'ap_nl_01', subject: 'CN=AP_NL_01, C=NL')]

    rows = described_class.all(parties: [party], tests: [], countries: { 'NL' => 'Pays-Bas' }, certificates:)

    expect(rows.map(&:country_name)).to eq(['Pays-Bas'])
  end

  it 'finds the certificate of a party the PMode no longer declares' do
    test = build(:connectivity_test, :acknowledged, party_name: 'AP_NL_01', party_identifier: '00000001805544434000',
      party_identifier_type: 'urn:cef.eu:names:identifier:EAS:0190')
    certificates = [TruststoreEntry.new(name: 'ap_nl_01', subject: 'CN=AP_NL_01, C=NL')]

    rows = described_class.all(parties: [], tests: [test], countries: { 'NL' => 'Pays-Bas' }, certificates:)

    expect(rows.map(&:country_name)).to eq(['Pays-Bas'])
  end
end
