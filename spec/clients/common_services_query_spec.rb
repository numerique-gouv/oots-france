require 'rails_helper'

RSpec.describe CommonServicesQuery do
  subject(:query) { described_class.new(CommonServicesInstance::EVIDENCE_BROKER, instance:, signature:) }

  let(:instance) { instance_double(CommonServicesInstance, base_url: 'https://query.example/eb/') }
  let(:signature) { instance_double(CommonServicesSignature, verify!: nil) }
  let(:parser) { RequirementsResponseParser }
  let(:body_and_headers) { common_services_answer('eb_requirements_fr') }
  let(:body) { body_and_headers.first }
  let(:headers) { body_and_headers.last }

  def stub_directory(status: 200, answer: body, sent: headers)
    stub_request(:get, 'https://query.example/eb/rest/search')
      .with(query: { queryId: 'une-requête' })
      .to_return(status:, body: answer, headers: sent)
  end

  def search = query.search({ queryId: 'une-requête' }, parser:)

  it 'asks the search endpoint of the instance the DNS named' do
    stubbed = stub_directory

    search

    expect(stubbed).to have_been_requested
  end

  # Chapter 3.6.2 makes both mandatory, and the version header is what gets a
  # v2.0 answer rather than the v1.0 shape the service falls back to.
  it 'announces the media type and the version it expects' do
    stub_directory

    search

    expect(a_request(:get, 'https://query.example/eb/rest/search').with(
      query: { queryId: 'une-requête' },
      headers: { 'Accept' => 'application/x-ebrs+xml', 'Accept-Version' => 'oots-cs:v2.0' },
    )).to have_been_made
  end

  it 'checks the signature of what it received, before anything reads it' do
    stub_directory

    search

    expect(signature).to have_received(:verify!)
      .with(body:, digest: headers['digest'], signature: headers['oots-response-sig'])
  end

  # The verification raises, and nothing must turn that into a usable answer.
  it 'lets a failed verification through rather than returning the answer' do
    stub_directory
    allow(signature).to receive(:verify!).and_raise(CommonServicesError, 'Signature invalide.')

    expect { search }.to raise_error(CommonServicesError, /Signature invalide/)
  end

  it 'reports an unreachable directory as a directory failure, not as a raw HTTP error' do
    stub_directory(status: 502, answer: 'Bad Gateway')

    expect { search }.to raise_error(CommonServicesError, /Annuaire injoignable/)
  end

  # The answer is parsed once, by the caller's own parser, and handed back read.
  it 'returns the answer already read by the parser it was given' do
    stub_directory

    expect(search).to be_a(RequirementsResponseParser)
    expect(search.requirements).to be_present
  end

  # The test environment runs on a null store, so caching has to be given a
  # real one here: three of these calls sit on the path of every evidence
  # request, and what the cache does with them is not incidental.
  describe 'the cache' do
    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    it 'asks the directory once for the same question' do
      stubbed = stub_directory

      2.times { search }

      expect(stubbed).to have_been_requested.once
    end

    # A key that did not depend on the parameters would hand one country the
    # provider of another, and nothing would say so.
    it 'keeps two queries apart when only their parameters differ' do
      first = stub_directory
      second = stub_request(:get, 'https://query.example/eb/rest/search')
        .with(query: { queryId: 'une-autre' })
        .to_return(body:, headers:)

      search
      query.search({ queryId: 'une-autre' }, parser:)

      expect(first).to have_been_requested.once
      expect(second).to have_been_requested.once
    end

    # Otherwise a passing outage would freeze for the whole of the cache
    # duration, and a refused signature would look like a cached answer.
    it 'caches nothing when the signature is refused' do
      stubbed = stub_directory
      allow(signature).to receive(:verify!).and_raise(CommonServicesError, 'Signature invalide.')

      2.times { expect { search }.to raise_error(CommonServicesError) }

      expect(stubbed).to have_been_requested.twice
    end

    # A refusal arrives with the same 200 and the same valid signature as an
    # answer. Cached, a directory's passing failure would go on being served
    # long after it recovered, and no log would say the answer came from here.
    it 'caches nothing when the directory refuses' do
      refused, refused_headers = common_services_answer('eb_requirements_vides')
      stubbed = stub_directory(answer: refused, sent: refused_headers)

      2.times { expect { search }.to raise_error(CommonServicesError, /EB:ERR:0001/) }

      expect(stubbed).to have_been_requested.twice
    end

    # Observing call counts within one example says nothing about how long the
    # entry lives: a freshness of zero would pass every other example here.
    it 'writes the answer with the freshness the deployment configured' do
      stub_directory
      allow(Rails.cache).to receive(:write).and_call_original

      search

      expect(Rails.cache).to have_received(:write)
        .with(anything, anything, hash_including(expires_in: Settings.common_services_cache_duration))
    end

    # The Evidence Broker answers both its queries at one address, so the same
    # parameters can reach two parsers: without the parser in the key, one
    # would read back what the other cached.
    it 'keeps entries apart by the parser that will read them back' do
      stub_directory
      search

      types, types_headers = common_services_answer('eb_evidence_types_fr')
      stub_directory(answer: types, sent: types_headers)
      query.search({ queryId: 'une-requête' }, parser: EvidenceTypesResponseParser)

      expect(a_request(:get, 'https://query.example/eb/rest/search')
        .with(query: { queryId: 'une-requête' })).to have_been_made.twice
    end

    # A cache is an optimisation: one that cannot be written must not cost the
    # answer that was already obtained.
    it 'still answers when the store refuses the write' do
      stub_directory
      allow(Rails.cache).to receive(:write).and_raise(Errno::ENOSPC)

      expect(search.requirements).to be_present
    end

    # The directory answering differently the second time is what tells a
    # cached body from a body merely fetched again.
    it 'serves what it cached, not what the directory says next' do
      stub_directory
      first = search.requirements.map(&:id)

      other, other_headers = common_services_answer('eb_evidence_types_fr')
      stub_directory(answer: other, sent: other_headers)

      expect(search.requirements.map(&:id)).to eq(first)
    end
  end
end
