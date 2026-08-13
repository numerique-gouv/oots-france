require 'rails_helper'

# Read against a real Finnish entry captured on the acceptance environment: it
# is the one whose access service declares `oots-edm:v2.0`.
RSpec.describe DataServicesResponseParser do
  subject(:providers) { described_class.new(body).providers }

  let(:body) { common_services_answer('dsd_data_services_fi').first }

  it 'reads the provider the directory holds for that evidence type' do
    expect(providers.size).to eq(1)
  end

  # The two are different values in the same entry, and conflating them would
  # address the message to the gateway as if it were the organisation.
  it 'tells the publisher apart from the access service carrying messages to it' do
    expect(providers.first.ebms_identity)
      .to eq(EbmsIdentity.new(id: 'FIKEHA02', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FI'))
    expect(providers.first.access_point)
      .to have_attributes(id: 'AP_FI_03', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FI')
  end

  it 'names the provider in each language the directory publishes' do
    expect(providers.first.descriptions).to include('EN' => 'Keha v. 2.0')
  end

  # Left to its default the address would be French, which would put the wrong
  # country in a message addressed to Finland.
  it 'reads the country from the publisher rather than defaulting to ours' do
    expect(providers.first.address.country).to eq('FI')
  end

  # Refused at construction and not when `providers` is first asked for: it is
  # on the strength of having built one of these that a caller caches the body
  # it was built from.
  it 'refuses an access service the directory published without a scheme' do
    stripped = body.sub(/schemeID="[^"]*"/, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /annoncé par l'annuaire/)
  end

  # One nesting level below the record: the slot is there, its access services
  # are not. Empty is not an answer a directory gives by succeeding.
  it 'refuses a data service carrying no access service' do
    stripped = body.gsub(%r{<sdg:AccessService>.*</sdg:AccessService>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /rien n'y était lisible/)
  end

  it 'refuses a publisher the directory published without an address' do
    stripped = body.sub(%r{<sdg:Address>.*?</sdg:Address>}m, '')

    expect { described_class.new(stripped) }
      .to raise_error(CommonServicesError, /adresse du fournisseur/)
  end
end
