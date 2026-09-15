require 'rails_helper'

RSpec.describe DemoRequirementCardComponent, type: :component do
  subject(:card) do
    described_class.new(wording:, askable: true, country_code: 'FR', country_name: 'France',
      zone: DemoRequestZoneComponent.new(outcome: nil))
  end

  let(:wording) do
    instance_double(DemoResolutionWording, nameable?: true, published_nothing?: false,
      evidence_type: 'FR - Test Evidence Type', evidence_type_language: 'en',
      provider: 'FR - Test Evidence Provider', provider_language: 'en',
      requirement: '(TEST) Test Requirement', requirement_language: 'en')
  end

  # Ce que le contrôleur Stimulus attend de la carte, et que rien d'autre ne
  # vérifie : l'un de ces trois attributs perdu, Stimulus ne s'attache pas, le
  # clic redevient une soumission de formulaire ordinaire, et le navigateur
  # quitte la page pour la réponse sans gabarit de `RequestsController#create`.
  it 'hands the browser the controller, the gesture it watches and the address it re-asks' do
    render_inline(card)

    element = page.find('[data-controller="demo-request"]', visible: :all)

    expect(element['data-action']).to eq('submit->demo-request#submit')
    expect(element['data-demo-request-url-value']).to eq('/admin/demo/demande')
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
end
