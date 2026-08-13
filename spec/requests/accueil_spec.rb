require 'rails_helper'

RSpec.describe 'Accueil' do
  describe 'GET /' do
    it 'renders an HTML page carrying the DSFR' do
      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(response.body).to include('fr-header')
    end

    it 'leads to the administration space' do
      get '/'

      expect(response.body).to include(admin_root_path)
    end

    # The header's navigation belongs to the administration space; here it
    # would offer what the page already does.
    it 'carries no navigation' do
      get '/'

      expect(response.parsed_body.css('.fr-nav')).to be_empty
    end
  end

  describe 'GET /up' do
    it 'answers without rendering a page' do
      get '/up'

      expect(response).to have_http_status(:ok)
    end
  end
end
