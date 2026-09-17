require 'rails_helper'

RSpec.describe DirectoryQueryComponent, type: :component do
  it 'shows the query the page read the answer of' do
    render_inline(described_class.new(query: :requirements,
      parameters: { 'procedure-id' => '00', 'country-code' => 'FR' }))

    expect(page).to have_css('code', text: EvidenceBrokerClient::REQUIREMENTS_QUERY)
    expect(page).to have_css('code', text: 'procedure-id')
    expect(page).to have_css('code', text: '00')
  end

  # A parameter the query did not carry is not one carried empty: showing it
  # would put in the reader's hands a query that was never sent.
  it 'leaves out a parameter that was not sent' do
    render_inline(described_class.new(query: :data_services, parameters: { 'country-code' => nil }))

    expect(page).to have_no_text('country-code')
  end

  # Forty characters of Semantic Repository URL say nothing to a reader
  # arriving on the page, and everything to one checking what it read.
  it 'shows the identifiers the answer turns on' do
    render_inline(described_class.new(query: :data_services,
      identifiers: { requirement: 'https://sr.acc.oots.tech.ec.europa.eu/x' }))

    expect(page).to have_text('Exigence')
    expect(page).to have_css('code', text: 'https://sr.acc.oots.tech.ec.europa.eu/x')
  end

  it 'says nothing of identifiers when the page turns on none' do
    render_inline(described_class.new(query: :data_services))

    expect(page).to have_no_text('Identifiants')
  end

  # The identifiers travel as symbols from five templates: nothing static ties
  # those call sites to the wordings this component says.
  it 'says every identifier its callers name' do
    named = Dir['app/views/**/*.erb']
      .flat_map { |path| File.read(path).scan(/identifiers: \{([^}]*)\}/m) }
      .flatten.flat_map { |group| group.scan(/(\w+):/) }.flatten.uniq

    expect_said(named.map { |identifier| "components.directory_query.identifiers.#{identifier}" })
  end
end
