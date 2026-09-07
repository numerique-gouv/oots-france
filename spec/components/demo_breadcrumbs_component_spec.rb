require 'rails_helper'

RSpec.describe DemoBreadcrumbsComponent, type: :component do
  it 'starts the trail where the whole section does' do
    render_inline(described_class.new(trail: [['Identification', nil]]))

    expect(page.all('.fr-breadcrumb__link').map(&:text))
      .to eq(['Espace d’administration', 'Démarche de démonstration', 'Identification'])
  end

  it 'stands on the procedure itself when the page adds nothing' do
    render_inline(described_class.new)

    expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Démarche de démonstration')
  end
end
