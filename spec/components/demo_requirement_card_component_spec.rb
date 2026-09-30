require 'rails_helper'

RSpec.describe DemoRequirementCardComponent, type: :component do
  # The pages of the walk live under the line they play, and the addresses a
  # component writes take it from the page being rendered.
  subject(:card) do
    described_class.new(wording:, country_code: 'FR', country_name: 'France',
      zone: DemoRequestZoneComponent.new(outcome: nil, requirement_uuid: uuid))
  end

  around { |example| with_request_url('/admin/demo/v2.0/documents') { example.run } }

  let(:uuid) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }
  let(:wording) do
    instance_double(DemoResolutionWording, nameable?: true, published_nothing?: false,
      evidence_type: 'FR - Test Evidence Type', evidence_type_language: 'en',
      provider: 'FR - Test Evidence Provider', provider_language: 'en',
      requirement: '(TEST) Test Requirement', requirement_language: 'en', requirement_uuid: uuid)
  end

  # Ce que le contrôleur Stimulus attend de la carte, et que rien d'autre ne
  # vérifie : l'un de ces trois attributs perdu, Stimulus ne s'attache pas, le
  # clic redevient une soumission de formulaire ordinaire, et le navigateur
  # quitte la page pour la réponse sans gabarit de `RequestsController#create`.
  #
  # L'adresse nomme l'exigence de cette carte : la page en porte une par
  # exigence demandable, et c'est la seule chose qui les distingue.
  it 'hands the browser the controller, the gesture it watches and the address it re-asks' do
    render_inline(card)

    element = page.find('[data-controller="demo-request"]', visible: :all)

    expect(element['data-action']).to eq('submit->demo-request#submit')
    expect(element['data-demo-request-url-value']).to eq("/admin/demo/v2.0/demande?exigence=#{uuid}")
  end

  # Une région remplacée en même temps que ce qu'elle annonce n'annonce rien :
  # elle vit sur l'élément qui persiste, pas dans le fragment que les réponses
  # remplacent.
  it 'keeps the announced region on the element the answers never replace' do
    render_inline(card)

    element = page.find('[data-controller="demo-request"]', visible: :all)

    expect(element['aria-live']).to eq('polite')
    expect(element).to have_css('.demo-request__body', visible: :all)
  end

  # Posted apart from the zone: the list is not part of what a change of
  # country replaces, and keeps the focus.
  it 'offers the countries it is given in a form of its own, outside the zone' do
    render_inline(described_class.new(wording:, country_code: 'FI', countries: [['🇫🇮 Finland (FI)', 'FI'], ['🇫🇷 France (FR)', 'FR']]))

    form = page.find('form.requirement-card__country')

    expect(form['action']).to eq("/admin/demo/v2.0/pays?exigence=#{uuid}")
    expect(form).to have_select('Country to request the document from', selected: '🇫🇮 Finland (FI)')
    expect(page).to have_no_css('.demo-request form.requirement-card__country')
  end

  # The server cannot say it could not be reached, so the sentence is rendered
  # with the list, hidden, and the controller shows it — outside what an answer
  # replaces, in the group the DSFR puts in its error state.
  it 'renders, hidden beside the list, what it says of a choice that got no answer' do
    render_inline(described_class.new(wording:, country_code: 'FI', countries: [['🇫🇮 Finland (FI)', 'FI']]))

    failure = page.find('.fr-select-group [data-demo-country-target="failure"]', visible: :hidden)

    expect(failure['id']).to eq("pays-#{uuid}-erreur")
    expect(failure[:class]).to eq('fr-error-text')
    expect(failure.text(:all).squish).to eq('The country could not be changed: this page could not reach the ' \
                                            'service. Choose it again, or reload the page.')
    expect(failure).to have_link('reload the page', href: '/admin/demo/v2.0/documents', visible: :hidden)
    expect(page).to have_no_css('[data-demo-country-target="resolution"] [data-demo-country-target="failure"]',
      visible: :all)
  end

  it 'offers no choice when it is given none' do
    render_inline(card)

    expect(page).to have_no_select
  end

  # RG12 of OOTS-237: a provider whose gateway does not announce the line of the
  # journey is named, and offers no button to ask it.
  describe 'a provider that does not support the line of the journey' do
    subject(:card) do
      described_class.new(wording:, country_code: 'FI', country_name: 'Finland', countries: [['🇫🇮 Finland (FI)', 'FI']],
        unspoken: EdmSpecification::V1_2)
    end

    it 'says so under the provider, offers neither button nor zone, and still offers the country' do
      render_inline(card)

      expect(page).to have_text('FR - Test Evidence Provider')
      expect(page).to have_text('This provider does not support OOTS 1.2')
      expect(page).to have_no_css('.demo-request')
      expect(page).to have_no_button
      expect(page).to have_select('Country to request the document from')
    end
  end
end
