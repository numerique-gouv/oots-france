require 'rails_helper'

RSpec.describe DemoRequirementCardComponent, type: :component do
  # The pages of the walk live under the line they play, and the addresses a
  # component writes take it from the page being rendered.
  subject(:card) do
    described_class.new(wording:, country_code: 'FR', country_name: 'France',
      zone: DemoRequestZoneComponent.new(outcome: nil, requirement_uuid: uuid))
  end

  around { |example| with_request_url('/admin/demo/v2.0/T1/documents') { example.run } }

  let(:uuid) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }
  let(:wording) do
    instance_double(DemoResolutionWording, nameable?: true, choosable?: false, published_nothing?: false,
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
    expect(element['data-demo-request-url-value']).to eq("/admin/demo/v2.0/T1/demande?exigence=#{uuid}")
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

  # RG7 of OOTS-253: a card the operator added carries a cross, named in words
  # for whoever cannot see its icon (RGAA 11.9); the others carry none.
  it 'carries a named cross only when it is removable' do
    render_inline(described_class.new(wording:, country_code: 'FR', removable: true))

    form = page.find('form.requirement-card__remove')
    expect(form['action']).to eq("/admin/demo/v2.0/T1/cartes/#{uuid}")
    expect(form).to have_css("input[name='_method'][value='delete']", visible: :all)
    expect(form).to have_button('Remove this document')

    render_inline(card)
    expect(page).to have_no_css('.requirement-card__remove')
  end

  # Posted apart from the zone: the list is not part of what a change of
  # country replaces, and keeps the focus.
  it 'offers the countries it is given in a form of its own, outside the zone' do
    render_inline(described_class.new(wording:, country_code: 'FI', countries: [['🇫🇮 Finland (FI)', 'FI'], ['🇫🇷 France (FR)', 'FR']]))

    form = page.find('form.requirement-card__country')

    expect(form['action']).to eq("/admin/demo/v2.0/T1/pays?exigence=#{uuid}")
    expect(form).to have_select('Country to request the document from', selected: '🇫🇮 Finland (FI)')
    expect(page).to have_no_css('.demo-request form.requirement-card__country')
  end

  # The server cannot say it could not be reached, so the sentence is rendered
  # with the list, hidden, and the controller shows it — outside what an answer
  # replaces, in the group the DSFR puts in its error state.
  it 'renders, hidden beside the list, what it says of a choice that got no answer' do
    render_inline(described_class.new(wording:, country_code: 'FI', countries: [['🇫🇮 Finland (FI)', 'FI']]))

    failure = page.find('.fr-select-group [data-demo-card-target="countryFailure"]', visible: :hidden)

    expect(failure['id']).to eq("pays-#{uuid}-erreur")
    expect(failure[:class]).to eq('fr-error-text')
    expect(failure.text(:all).squish).to eq('The country could not be changed: this page could not reach the ' \
                                            'service. Choose it again, or reload the page.')
    expect(failure).to have_link('reload the page', href: '/admin/demo/v2.0/T1/documents', visible: :hidden)
    expect(page).to have_no_css('[data-demo-card-target~="top"] [data-demo-card-target="countryFailure"]',
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
      expect(page).to have_css('.fr-alert.fr-alert--warning', text: 'This provider does not support OOTS 1.2')
      expect(page).to have_no_css('.demo-request')
      expect(page).to have_no_button
      expect(page).to have_select('Country to request the document from')
    end
  end

  # OOTS-263: the list of the evidence types the country publishes, where it
  # publishes several (requirement 26 of chapter 1 §2), in place of a sentence.
  describe 'a country publishing several evidence types' do
    let(:types) { [['Test Evidence Austria (AT)', 'aaaa', { lang: 'EN' }], ['Without Reauthentication', 'bbbb', { lang: 'EN' }]] }
    let(:countries) { [['🇦🇹 AT', 'AT']] }

    context 'when none is chosen' do
      let(:wording) do
        instance_double(DemoResolutionWording, nameable?: false, choosable?: true, published_nothing?: false,
          evidence_type: nil, evidence_type_uuid: nil, requirement: '(TEST) Test Requirement',
          requirement_language: 'en', requirement_uuid: uuid)
      end

      it 'offers them on a prompt, names nothing under the rule, and is no dead end' do
        render_inline(described_class.new(wording:, country_code: 'AT', countries:, evidence_types: types))

        form = page.find('form.requirement-card__evidence-type')
        expect(form['action']).to eq("/admin/demo/v2.0/T1/type_justificatif?exigence=#{uuid}")
        expect(form).to have_select('Document to request',
          options: ['Select a document', 'Test Evidence Austria (AT)', 'Without Reauthentication'])
        expect(form.first('option')['value']).to eq('')
        expect(form).to have_no_css('option[selected]')
        expect(page.find('.requirement-card__actions').text.squish).to be_empty
        expect(page).to have_no_css('.requirement-card--unsatisfiable')
        expect(page).to have_no_text('Satisfied by')
      end

      it 'renders, hidden beside the list, what it says of a choice that got no answer' do
        render_inline(described_class.new(wording:, country_code: 'AT', countries:, evidence_types: types))

        failure = page.find('[data-demo-card-target="typeFailure"]', visible: :hidden)
        expect(failure['id']).to eq("type-#{uuid}-erreur")
        expect(failure.text(:all).squish).to start_with('The document could not be changed')
      end
    end

    context 'when one is chosen and served by nobody' do
      let(:wording) do
        instance_double(DemoResolutionWording, nameable?: false, choosable?: true, published_nothing?: true,
          evidence_type: 'Without Reauthentication', evidence_type_uuid: 'bbbb',
          requirement: '(TEST) Test Requirement', requirement_language: 'en', requirement_uuid: uuid)
      end

      # RG4: the foot says it, the list stays, and the card is no dead end.
      it 'says so under the rule, without the prompt, still offering the types' do
        render_inline(described_class.new(wording:, country_code: 'AT', country_name: 'Austria', countries:,
          evidence_types: types))

        expect(page).to have_select('Document to request', selected: 'Without Reauthentication',
          options: ['Test Evidence Austria (AT)', 'Without Reauthentication'])
        expect(page).to have_text('No provider listed by Austria for this evidence')
        expect(page).to have_no_text('Evidence impossible to satisfy')
        expect(page).to have_no_css('.requirement-card--unsatisfiable')
      end
    end
  end

  # CA15 of OOTS-263: what stands above the rule, case by case.
  describe 'above the rule' do
    it 'says nothing on a card with its countries and a single type' do
      render_inline(described_class.new(wording:, country_code: 'FI', countries: [['🇫🇮 Finland (FI)', 'FI']]))

      expect(page.find('.fr-card__desc').text.squish).to be_empty
    end

    it 'names the country in its box alone on a card that offers no country' do
      render_inline(card)

      expect(page.find('.fr-card__desc').text.squish).to eq('🇫🇷 France (FR)')
      expect(page).to have_css('.fr-card__desc .country-tag')
    end

    it 'says the requirement is impossible to satisfy where the country publishes nothing' do
      unsatisfied = instance_double(DemoResolutionWording, nameable?: false, choosable?: false,
        published_nothing?: true, evidence_type: nil, requirement: '(TEST) Test Requirement',
        requirement_language: 'en', requirement_uuid: uuid)

      render_inline(described_class.new(wording: unsatisfied, country_code: 'FI', country_name: 'Finland',
        countries: [['🇫🇮 Finland (FI)', 'FI']]))

      expect(page.find('.fr-card__desc').text.squish).to eq('Evidence impossible to satisfy by 🇫🇮 Finland (FI)')
      expect(page).to have_css('.requirement-card--unsatisfiable')
    end
  end
end
