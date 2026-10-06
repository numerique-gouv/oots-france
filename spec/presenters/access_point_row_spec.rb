require 'rails_helper'

RSpec.describe AccessPointRow do
  let(:parties) do
    %w[AP_FR_01 AP_EL_01].map do |name|
      PmodeParty.new(name:, identifier: name, identifier_type: "urn:oasis:names:tc:ebcore:partyid-type:unregistered:#{name[3, 2]}",
        endpoint: 'https://msh')
    end
  end

  it 'lists the parties in the gateway\'s order, then the tests of parties it no longer declares' do
    tests = [
      build(:connectivity_test, party_name: 'AP_ZZ_01',
        party_identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:ZZ'),
      build(:connectivity_test, party_name: 'AP_EL_01'),
    ]

    rows = described_class.all(parties:, tests:, countries: { 'FR' => 'France', 'EL' => 'Grèce' })

    expect(rows.map { |row| [row.name, row.declared?] })
      .to eq([['AP_FR_01', true], ['AP_EL_01', true], ['AP_ZZ_01', false]])
    expect(rows.map(&:country_code)).to eq(%w[FR EL] + [nil])
  end

  it 'offers a test towards a declared party whose last test is settled' do
    rows = described_class.all(parties:, tests: [build(:connectivity_test, :acknowledged, party_name: 'AP_EL_01')],
      countries: {})

    expect(rows.map(&:testable?)).to eq([true, true])
    expect(rows.map(&:outcome)).to eq(%w[never_tested acknowledged])
  end

  it 'offers none towards a pending test, nor towards a party no longer declared' do
    tests = [build(:connectivity_test, party_name: 'AP_EL_01'), build(:connectivity_test, :acknowledged, party_name: 'AP_ZZ_01')]

    expect(described_class.all(parties:, tests:, countries: {}).map(&:testable?)).to eq([true, false, false])
  end
end
