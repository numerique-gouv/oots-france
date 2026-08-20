require 'rails_helper'

RSpec.describe CodeListClient do
  subject(:client) { described_class.new }

  it 'reads the French names of the procedure codes' do
    stub_code_list(procedures: { 'T3' => 'Demander la reconnaissance académique de diplômes' })

    expect(client.procedure_names).to eq('T3' => 'Demander la reconnaissance académique de diplômes')
  end

  # A name is an ornament: every page reading one says what it says without it,
  # so nothing about this reading may reach a controller.
  it 'answers no name at all rather than failing when the file cannot be read' do
    stub_request(:get, described_class::PROCEDURES).to_timeout

    expect(client.procedure_names).to be_empty
  end

  it 'answers no name at all when what comes back is not a code list' do
    stub_request(:get, described_class::PROCEDURES).to_return(status: 404, body: '<html>Not found</html>')

    expect(client.procedure_names).to be_empty
  end

  # A list that answers and yields nothing raises nothing, so without this the
  # only failure that erases every name of the console would be the only one to
  # leave no trace.
  it 'says so in the log when a list answers but yields no name' do
    stub_request(:get, described_class::PROCEDURES).to_return(body: '<gc:CodeList xmlns:gc="urn:x"/>')
    allow(Rails.logger).to receive(:warn)

    expect(client.procedure_names).to be_empty
    expect(Rails.logger).to have_received(:warn).with(/structure inattendue/)
  end

  # The same reasoning as the directories: a passing outage must not be served
  # for the whole freshness window.
  it 'never remembers an answer it could not read' do
    stub_request(:get, described_class::PROCEDURES).to_timeout
    allow(Rails.cache).to receive(:write)

    client.procedure_names

    expect(Rails.cache).not_to have_received(:write)
  end

  # ISO 3166 names a country with its article in brackets, which reads as a
  # footnote in a table cell.
  it 'reads the French names of the countries, without the article ISO 3166 adds' do
    stub_code_list(countries: { 'AT' => 'Autriche (l’)', 'CY' => 'Chypre' })

    expect(client.country_names).to eq('AT' => 'Autriche', 'CY' => 'Chypre')
  end

  # That article is what decides the preposition of a French sentence:
  # « en Autriche », but « aux Pays-Bas » and « à Chypre », which carries
  # none.
  it 'reads that article apart, for the countries that carry one' do
    stub_code_list(countries: { 'AT' => 'Autriche (l’)', 'NL' => 'Pays-Bas (les)', 'CY' => 'Chypre' })

    expect(client.country_articles).to eq('AT' => 'l’', 'NL' => 'les', 'CY' => nil)
  end

  # The test environment runs on a null store, so caching has to be given a
  # real one here: without it, the line that serves what was already read is
  # never executed by any example.
  describe 'the cache' do
    before { allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new) }

    it 'fetches the list once, however many pages ask for a name' do
      stub_code_list

      2.times { described_class.new.procedure_names }

      expect(a_request(:get, described_class::PROCEDURES)).to have_been_made.once
    end

    # Two lists, two keys: one served under the other's key would name a
    # country after a procedure.
    it 'keeps the two lists apart' do
      stub_code_list(procedures: { 'R1' => 'Naissance' }, countries: { 'FR' => 'France' })
      client = described_class.new

      expect(client.procedure_names).to eq('R1' => 'Naissance')
      expect(client.country_names).to eq('FR' => 'France')
    end

    # A cache is an optimisation: one that cannot be written must not cost the
    # names that were already read.
    it 'still answers when the store refuses the write' do
      stub_code_list
      allow(Rails.cache).to receive(:write).and_raise(Errno::ENOSPC)

      expect(described_class.new.procedure_names).to be_present
    end
  end

  it 'remembers what it read' do
    stub_code_list
    allow(Rails.cache).to receive(:write)

    client.procedure_names

    expect(Rails.cache).to have_received(:write)
      .with('code_lists/Procedures-CodeList', anything, expires_in: Settings.common_services_cache_duration)
  end
end
