require 'rails_helper'

RSpec.describe DirectoryBreadcrumbsComponent, type: :component do
  # The two crumbs every page of the directories hangs from, written once.
  it 'starts the trail where the whole section does' do
    render_inline(described_class.new(trail: [['Démarches', '/admin/common_services/procedures'], ['R1', nil]]))

    expect(page.all('.fr-breadcrumb__link').map(&:text))
      .to eq(['Espace d’administration', 'Annuaires centraux', 'Démarches', 'R1'])
  end

  # The last crumb is where the reader stands: no link, which is what marks it
  # as current for a screen reader.
  it 'leaves the last crumb unlinked, whatever the page passed' do
    render_inline(described_class.new(trail: [['Démarches', '/admin/common_services/procedures']]))

    expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Démarches')
    expect(page).to have_css(".fr-breadcrumb__link[href='/admin/common_services']", text: 'Annuaires centraux')
  end

  it 'stands on the directories themselves when the page adds nothing' do
    render_inline(described_class.new)

    expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Annuaires centraux')
  end
end
