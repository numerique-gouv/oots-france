require 'rails_helper'

RSpec.describe SearchFieldComponent, type: :component do
  subject(:field) do
    described_class.new(label: 'Rechercher un pays', id: 'recherche-pays', entries: '#liste > *',
      tally: '#decompte', empty: '#aucun')
  end

  it 'hands the browser what to narrow, what to tally and what to say when nothing is left' do
    render_inline(field)

    input = page.find('input')

    expect(input['data-filter']).to eq('#liste > *')
    expect(input['data-filter-tally']).to eq('#decompte')
    expect(input['data-filter-empty']).to eq('#aucun')
  end

  # A field whose only label is its placeholder has none left the moment
  # someone types into it.
  it 'keeps a label off screen behind the placeholder' do
    render_inline(field)

    expect(page).to have_css('label.fr-sr-only[for="recherche-pays"]', text: 'Rechercher un pays', visible: :all)
    expect(page).to have_css('input#recherche-pays[placeholder="Rechercher un pays"]')
  end

  # Nothing is submitted: the field filters what is already rendered.
  it 'carries no form and no button' do
    render_inline(field)

    expect(page).to have_no_css('form')
    expect(page).to have_no_button
  end

  # The magnifier doubles the placeholder, which already says « Rechercher ».
  it 'flies a magnifier no screen reader announces' do
    render_inline(field)

    expect(page).to have_css('.fr-icon-search-line[aria-hidden="true"]', visible: :all)
  end

  it 'leaves out what the caller did not name' do
    render_inline(described_class.new(label: 'Rechercher', id: 'recherche', entries: '#liste > *'))

    expect(page).to have_no_css('input[data-filter-tally]')
    expect(page).to have_no_css('input[data-filter-empty]')
  end
end
