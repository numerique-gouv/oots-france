require 'rails_helper'

RSpec.describe 'Admin::DevelopmentSessions' do
  it 'opens the space without ProConnect, to an agent of the first admitted domain' do
    undeclare_pro_connect

    post admin_development_session_path

    expect(response).to redirect_to(admin_root_path)
    expect(session[:agent_email]).to eq('administrateur.demonstration@numerique.gouv.fr')
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it 'leads to the page the guard turned away' do
    get admin_journal_root_path

    post admin_development_session_path

    expect(response).to redirect_to(admin_journal_root_path)
  end

  it 'is offered on the login page' do
    get new_admin_session_path

    expect(response.parsed_body.css("form[action='/admin/session/developpement'] button").text)
      .to eq('Se connecter sans ProConnect (Dev)')
  end

  # The route is drawn by `Rails.env` alone: in production the address does
  # not exist, and the action refuses should it be reached some other way.
  context 'when the application runs in production' do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('production'))
      Rails.application.reload_routes!
    end

    after do
      allow(Rails).to receive(:env).and_call_original
      Rails.application.reload_routes!
    end

    it 'draws no route for it' do
      expect { Rails.application.routes.recognize_path('/admin/session/developpement', method: :post) }
        .to raise_error(ActionController::RoutingError)
    end

    it 'answers the address as an unknown one, and opens nothing' do
      post '/admin/session/developpement'

      expect(response).to have_http_status(:not_found)
      expect(session[:agent_email]).to be_nil
    end

    it 'refuses in the action itself' do
      controller = Admin::DevelopmentSessionsController.new

      expect { controller.create }.to raise_error(ActionController::RoutingError)
    end

    it 'offers no button on the login page' do
      stub_pro_connect

      get new_admin_session_path

      expect(response.body).not_to include('Se connecter sans ProConnect (Dev)')
    end
  end
end
