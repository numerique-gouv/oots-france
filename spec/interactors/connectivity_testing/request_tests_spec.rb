require 'rails_helper'

RSpec.describe ConnectivityTesting::RequestTests do
  def party(name, identifier_type: "urn:oasis:names:tc:ebcore:partyid-type:unregistered:#{name[3, 2]}")
    PmodeParty.new(name:, identifier: name, identifier_type:, endpoint: nil)
  end

  let(:parties) { [party('AP_EL_01'), party('AP_FI_01'), party('AP_XX_01', identifier_type: nil)] }

  it 'tests every addressable party when none is named' do
    expect { described_class.call(parties:, party: nil) }
      .to have_enqueued_job(SubmitConnectivityTestJob).exactly(:twice)
    expect(ConnectivityTest.pluck(:party_name)).to contain_exactly('AP_EL_01', 'AP_FI_01')
  end

  it 'tests only the party named' do
    described_class.call(parties:, party: 'AP_FI_01')

    expect(ConnectivityTest.pluck(:party_name)).to eq(['AP_FI_01'])
  end

  it 'tests nothing the PMode does not declare, nor a party it cannot address' do
    expect { described_class.call(parties:, party: 'AP_ZZ_01') }.not_to have_enqueued_job
    expect { described_class.call(parties:, party: 'AP_XX_01') }.not_to have_enqueued_job
  end
end
