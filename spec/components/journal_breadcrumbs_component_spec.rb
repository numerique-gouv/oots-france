require 'rails_helper'

RSpec.describe JournalBreadcrumbsComponent, type: :component do
  # The two crumbs every page of the log hangs from, written once.
  it 'starts the trail where the whole section does' do
    render_inline(described_class.new(trail: [['Conversations', '/admin/journal/conversations'], ['abc-123', nil]]))

    expect(page.all('.fr-breadcrumb__link').map(&:text))
      .to eq(['Espace d’administration', 'Journal des échanges', 'Conversations', 'abc-123'])
  end

  # The last crumb is where the reader stands: no link, which is what marks it
  # as current for a screen reader.
  it 'leaves the last crumb unlinked, whatever the page passed' do
    render_inline(described_class.new(trail: [['Conversations', '/admin/journal/conversations']]))

    expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Conversations')
    expect(page).to have_css(".fr-breadcrumb__link[href='/admin/journal']", text: 'Journal des échanges')
  end

  it 'stands on the log itself when the page adds nothing' do
    render_inline(described_class.new)

    expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Journal des échanges')
  end
end
