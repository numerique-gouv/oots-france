require 'rails_helper'

# OOTS-321: the sign-out of FranceConnect+ on the line of the trail, on the four
# screens of the walk, whenever the entrance holds an identity and its journey,
# showing the name of the user it signs out.
# It submits to the address of the walk held, whatever screen it is chosen
# from: the return lands on the home of the procedure that address names.
RSpec.describe 'The sign-out on the line of the trail of the demonstration' do
  def page = response.parsed_body

  def trail_sign_out = page.at_css('.fr-breadcrumb').ancestors('.fr-grid-row').first&.at_css('form button')

  def screens
    {
      'the choice of the line' => admin_demo_root_path,
      'the choice of the procedure, under another line' => admin_demo_procedures_path(version: 'v1.2'),
      'the home of the procedure' => admin_demo_home_path(version: 'v2.0', procedure: 'T1'),
      'the documents page' => admin_demo_documents_path(version: 'v2.0', procedure: 'T1'),
    }
  end

  def stub_the_four_screens
    stub_code_list
    stub_directory_resolution
    stub_directory('eb', 'requirements-by-procedure', 'eb_requirements_fr')
    stub_directory('eb', 'evidence-types-by-requirement', 'eb_evidence_types_fi')
    stub_directory('dsd', 'dataservices-by-evidencetype', 'dsd_data_services_fi')
  end

  before do
    sign_in
    declare_france_connect(fake_france_connect)
    stub_the_four_screens
  end

  context 'when the console holds a walk under 2.0 and T1' do
    before { identify_demo_user(version: 'v2.0', procedure: 'T1') }

    # CA1, CA4 and CA6 by the address the button submits to.
    it 'offers it on each of the four screens, submitting to the address of the walk held' do
      screens.each do |screen, path|
        get path

        expect(response).to have_http_status(:ok), screen
        button = trail_sign_out
        expect(button&.text&.squish).to eq('Freja Marie Sørensen'), screen
        expect(button['aria-label']).to eq('Se déconnecter de FranceConnect+ (Freja Marie Sørensen)')
        expect(button['title']).to eq('Se déconnecter de FranceConnect+ (Freja Marie Sørensen)')
        expect(button['class']).to include('fr-btn--sm', 'fr-btn--tertiary', 'fr-btn--icon-left', 'fr-icon-logout-box-r-line')
        form = button.ancestors('form').first
        expect(form['action']).to eq('/admin/demo/v2.0/T1/identification'), screen
        expect(form.at_css('input[name=_method]')['value']).to eq('delete')
      end
    end

    it 'names it in English when the page is read in English' do
      get admin_demo_root_path(locale: 'en')
      follow_redirect! if response.redirect?

      expect(trail_sign_out['aria-label']).to eq('Sign out of FranceConnect+ (Freja Marie Sørensen)')
    end

    # CA8: the button of the identity card stays where it was.
    it 'leaves the button of the identity card where it was' do
      get admin_demo_documents_path(version: 'v2.0', procedure: 'T1')

      expect(page.at_css('main .identity-card .identity-card__action button')).to be_present
    end
  end

  # The validity `require_journey` asks of the pages past the sign-in: an
  # identity without its journey holds no walk to close.
  context 'when the console holds an identity whose journey is gone' do
    before do
      identify_demo_user
      allow(Demo::Journey).to receive(:from_session).and_return(nil)
    end

    it 'offers it on none of the screens before the sign-in' do
      screens.except('the documents page').each do |screen, path|
        get path

        expect(response).to have_http_status(:ok), screen
        expect(page.css('button[aria-label^="Se déconnecter de FranceConnect+"]')).to be_empty, screen
      end
    end
  end

  # CA2: no identity, nothing to close.
  context 'when the console holds no walk' do
    it 'offers it on none of the screens before the sign-in' do
      screens.except('the documents page').each do |screen, path|
        get path

        expect(response).to have_http_status(:ok), screen
        expect(page.css('button[aria-label^="Se déconnecter de FranceConnect+"]')).to be_empty, screen
      end
    end
  end
end
