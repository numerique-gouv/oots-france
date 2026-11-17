require 'rails_helper'

RSpec.describe StudentStatus do
  subject(:status) { described_class.new(ApiParticulierStubs::MARTIN_JACQUES.to_json) }

  it 'reads the identity the registry certifies' do
    expect(status.identity).to have_attributes(family_name: 'Martin', given_name: 'Jacques',
      date_of_birth: '2004-01-01')
  end

  it 'reads each admission of the year' do
    expect(status.admissions.sole).to have_attributes(
      institution: 'Université Paris Nanterre', institution_code: '0330023W', start_date: '2024-10-01',
      end_date: '2025-08-31', enrolled: true, scheme: 'formation initiale', commune_code: '92000',
    )
  end

  it 'reads an admission the registry gives without institution or scheme' do
    admission = ApiParticulierStubs::MARTIN_JACQUES['admissions'].sole
      .merge('etablissement_etudes' => nil, 'regime_formation' => nil)
    status = described_class.new(ApiParticulierStubs::MARTIN_JACQUES.merge('admissions' => [admission]).to_json)

    expect(status.admissions.sole).to have_attributes(institution: nil, institution_code: nil, scheme: nil,
      enrolled: true)
  end
end
