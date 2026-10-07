require 'rails_helper'

RSpec.describe 'Admin::Demo::Versions' do
  describe 'GET /admin/demo' do
    before { sign_in }

    # CA1 of OOTS-237: the console's screen, in French, two cards in the order
    # France prefers the lines, and no directory asked — WebMock would refuse
    # any request nothing stubs.
    it 'offers the two lines, 2.0 first, each leading to the choice of the procedure under its segment' do
      get admin_demo_root_path

      expect(response).to have_http_status(:ok)
      cartes = response.parsed_body.css('main .fr-card')
      expect(cartes.map { |carte| carte.at_css('.fr-card__title').text.squish }).to eq(['OOTS 2.0', 'OOTS 1.2'])
      expect(cartes.map { |carte| carte.at_css('a')['href'] }).to eq(['/admin/demo/v2.0', '/admin/demo/v1.2'])
      expect(cartes.map { |carte| carte.at_css('.fr-card__desc').text.squish })
        .to eq(['The most recent version, still implemented by few member states',
                'The version supported by most member states'])
    end

    it 'stands under the trail of the console' do
      get admin_demo_root_path

      expect(response.parsed_body.css('.fr-breadcrumb__link').map { |crumb| crumb.text.squish })
        .to eq(['Espace d’administration', 'Demo'])
    end
  end

  # CA2 of OOTS-237, CA2 of OOTS-253: under its line and its procedure, the
  # sign-in page, which nothing writes before the identification.
  describe 'GET /admin/demo/v1.2/T1' do
    before do
      sign_in
      stub_code_list
      stub_demonstration_requirements
      declare_france_connect(fake_france_connect)
    end

    it 'is the sign-in page, submitting under its segment, its trail following its address' do
      get admin_demo_home_path(version: 'v1.2', procedure: 'T1')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css('main form')['action']).to eq('/admin/demo/v1.2/T1/identification')
      expect(response.parsed_body.css('.fr-breadcrumb__link').map { |crumb| crumb.text.squish })
        .to eq(['Espace d’administration', 'Demo', '1.2', 'Procedure T1'])
      expect(response.parsed_body.at_css('.fr-breadcrumb').css('a[href]').pluck('href'))
        .to eq(['/admin', '/admin/demo', '/admin/demo/v1.2'])
      expect(session[:france_connect]).to be_nil
    end

    # RG10: a segment of no line France speaks is an address that does not exist.
    it 'has no neighbour under a line France does not speak' do
      get '/admin/demo/v1.0'

      expect(response).to have_http_status(:not_found)
    end

    # RG3 of OOTS-253: nor under a code no request may name, `R-EDM-REQ-C003`
    # being FATAL.
    it 'has no neighbour under a code neither the list nor the system check is' do
      get '/admin/demo/v1.2/Z9'

      expect(response).to have_http_status(:not_found)
    end
  end
end
