require 'rails_helper'

# One crumb per segment of the address: the console, the screen the line is
# chosen on, the line, then the page being read.
RSpec.describe DemoBreadcrumbsComponent, type: :component do
  context 'when a page of the walk is read' do
    it 'hangs the page under the line, and the line under the demonstration' do
      render_inline(described_class.new(specification: EdmSpecification::V2_0, trail: [['Your documents', nil]]))

      expect(page.all('.fr-breadcrumb__link').map(&:text))
        .to eq(['Espace d’administration', 'Démo', '2.0', 'Your documents'])
      expect(page).to have_link('Démo', href: '/admin/demo')
      expect(page).to have_link('2.0', href: '/admin/demo/v2.0')
    end

    it 'stands on the line itself on its sign-in page' do
      render_inline(described_class.new(specification: EdmSpecification::V2_0))

      expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: '2.0')
    end
  end

  context 'when the screen the line is chosen on is read' do
    it 'stands on the demonstration, under the console' do
      render_inline(described_class.new)

      expect(page.all('.fr-breadcrumb__link').map(&:text)).to eq(['Espace d’administration', 'Démo'])
      expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Démo')
    end
  end
end
