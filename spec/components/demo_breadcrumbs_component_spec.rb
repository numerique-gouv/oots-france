require 'rails_helper'

# One crumb per segment of the address: the console, the screen the line is
# chosen on, the line, the procedure, then the page being read.
RSpec.describe DemoBreadcrumbsComponent, type: :component do
  context 'when a page of the walk is read' do
    it 'hangs the page under the procedure, the procedure under the line, and the line under the demonstration' do
      render_inline(described_class.new(specification: EdmSpecification::V2_0, procedure: 'T1',
        trail: [['Vos justificatifs', nil]]))

      expect(page.all('.fr-breadcrumb__link').map(&:text))
        .to eq(['Administration', 'Démo', '2.0', 'Démarche T1', 'Vos justificatifs'])
      expect(page).to have_link('Démo', href: '/admin/demo')
      expect(page).to have_link('2.0', href: '/admin/demo/v2.0')
      expect(page).to have_link('Démarche T1', href: '/admin/demo/v2.0/T1')
    end

    it 'stands on the procedure itself on its sign-in page' do
      render_inline(described_class.new(specification: EdmSpecification::V2_0, procedure: 'T1'))

      expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Démarche T1')
    end

    it 'stands on the line itself on the screen its procedure is chosen on' do
      render_inline(described_class.new(specification: EdmSpecification::V2_0))

      expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: '2.0')
    end
  end

  context 'when the screen the line is chosen on is read' do
    it 'stands on the demonstration, under the console' do
      render_inline(described_class.new)

      expect(page.all('.fr-breadcrumb__link').map(&:text)).to eq(%w[Administration Démo])
      expect(page).to have_css(".fr-breadcrumb__link[aria-current='true']", text: 'Démo')
    end
  end

  # OOTS-321: the sign-out of FranceConnect+ shares the line of the trail when
  # the entrance holds a walk, and is absent when it holds none.
  context 'when an address to sign out to and the identity it closes are given' do
    let(:identity) { Demo::UserIdentity.new(given_name: 'Freja Marie', family_name: 'Sørensen') }

    it 'puts a button naming the user, submitting a DELETE to it, on the line of the trail, right of it' do
      render_inline(described_class.new(sign_out: '/admin/demo/v2.0/T1/identification', identity:))

      row = page.find('.fr-grid-row')
      expect(row).to have_css('.fr-col nav.fr-breadcrumb')
      form = row.find('.fr-col-auto form[action="/admin/demo/v2.0/T1/identification"]')
      expect(form).to have_field('_method', with: 'delete', type: :hidden)
      button = form.find('button')
      expect(button.text.squish).to eq('Freja Marie Sørensen')
      expect(button['aria-label']).to eq('Se déconnecter de FranceConnect+ (Freja Marie Sørensen)')
    end
  end

  context 'when no address to sign out to is given' do
    it 'renders the trail alone' do
      render_inline(described_class.new)

      expect(page).to have_no_css('.fr-grid-row')
      expect(page).to have_no_css('form')
    end
  end
end
