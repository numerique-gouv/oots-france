require 'rails_helper'

# CA5: the domain of the `email` claim, compared to the admitted ones to the
# character and regardless of case.
RSpec.describe Agent do
  def agent(email) = described_class.new(email:)

  it 'takes as its domain what follows the last @' do
    expect(agent('"a@b"@numerique.gouv.fr').domain).to eq('numerique.gouv.fr')
  end

  it 'admits an address of an admitted domain whatever its case' do
    expect(agent('Agent@NUMERIQUE.gouv.fr')).to be_admitted_by(%w[numerique.gouv.fr])
  end

  it 'refuses a subdomain the list does not name' do
    expect(agent('agent@sous.numerique.gouv.fr')).not_to be_admitted_by(%w[numerique.gouv.fr])
  end

  it 'admits a subdomain the list names' do
    expect(agent('agent@sous.numerique.gouv.fr'))
      .to be_admitted_by(%w[numerique.gouv.fr sous.numerique.gouv.fr])
  end

  it 'refuses a domain that only ends like an admitted one' do
    expect(agent('agent@faux-numerique.gouv.fr')).not_to be_admitted_by(%w[numerique.gouv.fr])
  end

  it 'refuses what is not an address' do
    expect(agent('numerique.gouv.fr')).not_to be_admitted_by(%w[numerique.gouv.fr])
    expect(agent(nil)).not_to be_admitted_by(%w[numerique.gouv.fr])
  end
end
