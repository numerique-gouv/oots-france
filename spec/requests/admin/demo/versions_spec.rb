require 'rails_helper'

RSpec.describe 'Admin::Demo::Versions' do
  describe 'GET /admin/demo' do
    before { sign_in }

    # CA1 of OOTS-237: the console's screen, in French, two cards in the order
    # France prefers the lines, and no directory asked — WebMock would refuse
    # any request nothing stubs.
    it 'offers the two lines, 2.0 first, each leading to the sign-in page under its segment' do
      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      cartes = response.parsed_body.css('main .fr-card')
      expect(cartes.map { |carte| carte.at_css('.fr-card__title').text.squish }).to eq(['OOTS 2.0', 'OOTS 1.2'])
      expect(cartes.map { |carte| carte.at_css('a')['href'] }).to eq(['/admin/demo/v2.0', '/admin/demo/v1.2'])
      expect(cartes.map { |carte| carte.at_css('.fr-card__desc').text.squish })
        .to eq(['La version la plus récente mais encore peu implémentée',
                'La version supportée par la majorité des états membres'])
    end

    it 'stands under the trail of the console' do
      get admin_demo_root_path

      expect(response.parsed_body.css('.fr-breadcrumb__link').map { |crumb| crumb.text.squish })
        .to eq(['Espace d’administration', 'Démo'])
    end
  end

  # CA2: the card leads to the sign-in page of its line, which nothing writes
  # before the identification.
  describe 'GET /admin/demo/v1.2' do
    before do
      sign_in
      stub_code_list
      stub_demonstration_requirements
      declare_france_connect(fake_france_connect)
    end

    it 'is the sign-in page, submitting under its segment, its trail following its address' do
      get admin_demo_home_path(version: 'v1.2')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css('main form')['action']).to eq('/admin/demo/v1.2/identification')
      expect(response.parsed_body.css('.fr-breadcrumb__link').map { |crumb| crumb.text.squish })
        .to eq(['Espace d’administration', 'Démo', '1.2'])
      expect(session[:france_connect]).to be_nil
    end

    # RG10: a segment of no line France speaks is an address that does not exist.
    it 'has no neighbour under a line France does not speak' do
      get '/admin/demo/v1.0'

      expect(response).to have_http_status(:not_found)
    end
  end
end
