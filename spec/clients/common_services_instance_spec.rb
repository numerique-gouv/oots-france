require 'rails_helper'

RSpec.describe CommonServicesInstance do
  subject(:instance) { described_class.new(described_class::DATA_SERVICE_DIRECTORY) }

  let(:resolver) { instance_double(Resolv::DNS) }
  let(:records) { [naptr('!.*!https://query.cs.acc.oots.tech.ec.europa.eu/dsd/!')] }

  before do
    allow(Resolv::DNS).to receive(:open).and_yield(resolver)
    allow(resolver).to receive(:getresources).and_return(records)
  end

  def naptr(regexp, order: 100, preference: 10, flags: 'U')
    Resolv::DNS::Resource::IN::NAPTR.new(order, preference, flags, '', regexp, Resolv::DNS::Name.create('.'))
  end

  it 'builds the name chapter 3.4 templates, in lowercase' do
    expect(instance.name).to eq('fr.dsd.v1.cs.acc.oots.tech.ec.europa.eu')
  end

  # The base URL cannot be built from the template: in production the record
  # answers `https://query.cs.oots.tech.ec.europa.eu/`, with no `prod` segment.
  it 'takes the base URL from the record rather than deriving it' do
    expect(instance.base_url).to eq('https://query.cs.acc.oots.tech.ec.europa.eu/dsd/')
  end

  # RFC 3403 orders by `order` first, then by `preference` within it.
  it 'prefers the record of lowest order, then of lowest preference' do
    allow(resolver).to receive(:getresources).and_return([
      naptr('!.*!https://tardif!', order: 200, preference: 1),
      naptr('!.*!https://retenu!', order: 100, preference: 20),
      naptr('!.*!https://ecarte!', order: 100, preference: 30),
    ])

    expect(instance.base_url).to eq('https://retenu')
  end

  # A non-terminal record names another lookup rather than a URI, and following
  # it is not what chapter 3.4 describes.
  it 'ignores a record that is not terminal' do
    allow(resolver).to receive(:getresources).and_return([naptr('!.*!https://ailleurs!', flags: 'S')])

    expect { instance.base_url }.to raise_error(CommonServicesError, /Aucun enregistrement NAPTR/)
  end

  it 'says so when the country publishes no record' do
    allow(resolver).to receive(:getresources).and_return([])

    expect { instance.base_url }.to raise_error(CommonServicesError, /Aucun enregistrement NAPTR/)
  end

  it 'says so when the record carries no substitution it can read' do
    allow(resolver).to receive(:getresources).and_return([naptr('pas-une-substitution')])

    expect { instance.base_url }.to raise_error(CommonServicesError, /illisible/)
  end

  # This cache is what keeps a NAPTR lookup off every evidence request: the
  # URL is rebuilt before the query's own cache is consulted, so a hit there
  # still passes through here.
  it 'resolves the name only once' do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

    2.times { instance.base_url }

    expect(resolver).to have_received(:getresources).once
  end

  it 'reports a resolver failure as a directory failure' do
    allow(resolver).to receive(:getresources).and_raise(Resolv::ResolvError, 'DNS injoignable')

    expect { instance.base_url }.to raise_error(CommonServicesError, /Résolution DNS impossible/)
  end

  # Without it, an exhausted resolver returns an empty list and is reported as
  # a country that published no record — and the nameservers have to be carried
  # over, a bare hash leaving `Resolv` with `0.0.0.0` alone.
  it 'asks the resolver to raise its timeouts, keeping the configured nameservers' do
    instance.base_url

    expect(Resolv::DNS).to have_received(:open)
      .with(hash_including(raise_timeout_errors: true, nameserver: Resolv::DNS::Config.default_config_hash[:nameserver]))
  end

  context 'when the environment names the instance' do
    around do |example|
      ENV['URL_BASE_DATA_SERVICE_DIRECTORY'] = 'http://web:4001/dsd'
      example.run
    ensure
      ENV.delete('URL_BASE_DATA_SERVICE_DIRECTORY')
    end

    it 'answers that address' do
      expect(instance.base_url).to eq('http://web:4001/dsd')
    end

    # A named instance is one no record describes: resolving anyway would fail
    # wherever DNS is filtered, which is the case this exists to serve.
    it 'resolves nothing' do
      instance.base_url

      expect(resolver).not_to have_received(:getresources)
    end

    it 'leaves the other service to its record' do
      broker = described_class.new(described_class::EVIDENCE_BROKER)

      expect(broker.base_url).to eq('https://query.cs.acc.oots.tech.ec.europa.eu/dsd/')
    end
  end
end
