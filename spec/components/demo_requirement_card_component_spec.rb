require 'rails_helper'

RSpec.describe DemoRequirementCardComponent, type: :component do
  # The pages of the walk live under the line they play, and the addresses a
  # component writes take it from the page being rendered.
  subject(:card) do
    described_class.new(wording:, country_code: 'FR', country_name: 'France', zone:)
  end

  around { |example| with_request_url('/admin/demo/v2.0/T1/documents') { example.run } }

  let(:uuid) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }
  let(:zone) do
    type = DemoRequestZoneComponent::Type.new(uuid: 'aaaa', name: 'FR - Test Evidence Type', language: 'en')

    DemoRequestZoneComponent.new(requirement_uuid: uuid,
      blocks: [DemoRequestComponent.new(outcome: nil, requirement_uuid: uuid, evidence_type: type)])
  end
  let(:wording) { card_wording(lines: [line]) }

  def line(**attributes)
    instance_double(DemoResolutionWording, asking?: false, answered?: false, nameable?: true, published_nothing?: false,
      evidence_type: 'FR - Test Evidence Type', evidence_type_language: 'en', evidence_type_uuid: 'aaaa',
      provider: 'FR - Test Evidence Provider', provider_language: 'en', **attributes)
  end

  # What a line says, less what `DirectoryValueComponent` adds for a screen
  # reader after each value the directories publish.
  def said(element) = element.text.squish.gsub(', retrieved from the common services', '')

  def card_wording(lines:, **attributes)
    instance_double(DemoCardWording, lines:, nameable?: lines.any? && lines.all?(&:nameable?), choosable?: false,
      combination_id: 'liste', published_nothing?: false, requirement: '(TEST) Test Requirement',
      requirement_language: 'en', requirement_uuid: uuid, **attributes)
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
        unspoken: { 'aaaa' => EdmSpecification::V1_2 })
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

  # OOTS-270: the list of the combinations the country publishes, where it
  # publishes several (chapter 3.2.2 §2.3), in place of a sentence.
  describe 'a country publishing several combinations' do
    let(:combinations) do
      [['Simple test evidence', 'simple', { lang: 'EN' }], ['Compound test evidence', 'compound', { lang: 'EN' }]]
    end
    let(:countries) { [['🇬🇷 EL', 'EL']] }

    context 'when none is chosen' do
      let(:wording) { card_wording(lines: [], choosable?: true, combination_id: nil) }

      it 'offers them on a prompt, names nothing under the rule, and is no dead end' do
        render_inline(described_class.new(wording:, country_code: 'EL', countries:, combinations:))

        form = page.find('form.requirement-card__evidence-type')
        expect(form['action']).to eq("/admin/demo/v2.0/T1/combinaison?exigence=#{uuid}")
        expect(form).to have_select('Document to request',
          options: ['Select a document', 'Simple test evidence', 'Compound test evidence'])
        expect(form.first('option')['value']).to eq('')
        expect(form).to have_no_css('option[selected]')
        expect(page.find('.requirement-card__actions').text.squish).to be_empty
        expect(page).to have_no_css('.requirement-card--unsatisfiable')
      end

      it 'renders, hidden beside the list, what it says of a choice that got no answer' do
        render_inline(described_class.new(wording:, country_code: 'EL', countries:, combinations:))

        failure = page.find('[data-demo-card-target="combinationFailure"]', visible: :hidden)
        expect(failure['id']).to eq("combinaison-#{uuid}-erreur")
        expect(failure.text(:all).squish).to start_with('The document could not be changed')
      end
    end

    # CA4: a line with no provider says so on its line, the others keep
    # theirs, and the card offers no button and is no dead end.
    context 'when one is chosen and one of its types is served by nobody' do
      let(:wording) do
        card_wording(choosable?: true, combination_id: 'compound', lines: [
          line(evidence_type: 'Projectathon test evidence', evidence_type_uuid: 'bbbb',
            provider: 'Ministry of Education'),
          line(nameable?: false, published_nothing?: true, evidence_type: 'Simple test evidence',
            evidence_type_uuid: 'cccc', provider: nil),
        ])
      end

      it 'names the provider of each line it can, says the other has none, and offers no button' do
        render_inline(described_class.new(wording:, country_code: 'EL', country_name: 'Greece', countries:,
          combinations:))

        expect(page).to have_select('Document to request', selected: 'Compound test evidence',
          options: ['Simple test evidence', 'Compound test evidence'])
        expect(page.all('[data-demo-card-line]').map { |found| said(found) }).to eq(
          ['Projectathon test evidence from Ministry of Education', '⚠️No provider listed by Greece for this evidence'],
        )
        expect(page).to have_no_button
        expect(page).to have_no_text('Evidence impossible to satisfy')
        expect(page).to have_no_css('.requirement-card--unsatisfiable')
      end
    end
  end

  # CA2 of OOTS-270: a single combination of several types offers no list, and
  # names a provider on a line per type, in the order of the list.
  describe 'a single combination of several types' do
    let(:wording) do
      card_wording(lines: [
        line(evidence_type: 'Projectathon test evidence', evidence_type_uuid: 'bbbb', provider: 'Ministry of Education'),
        line(evidence_type: 'Simple test evidence', evidence_type_uuid: 'cccc', provider: 'Ministry of Digital Governance'),
      ])
    end

    it 'offers no list, and names each type with its provider, on a line of its own' do
      render_inline(described_class.new(wording:, country_code: 'EL', countries: [['🇬🇷 EL', 'EL']], zone:))

      expect(page).to have_no_select('Document to request')
      expect(page.all('[data-demo-card-line]').map { |found| [found['data-demo-card-line'], said(found)] }).to eq([
        ['bbbb', 'Projectathon test evidence from Ministry of Education'],
        ['cccc', 'Simple test evidence from Ministry of Digital Governance'],
      ])
      expect(page).to have_css('[data-demo-card-target="request"] .demo-request', visible: :all)
    end

    # RG3: a combination is satisfied only by each of its types, and the
    # country publishes no other.
    it 'is a dead end where one type has no provider' do
      wording = card_wording(lines: [line, line(nameable?: false, published_nothing?: true, evidence_type_uuid: 'cccc')])

      render_inline(described_class.new(wording:, country_code: 'EL', country_name: 'Greece', countries: [['🇬🇷 EL', 'EL']]))

      expect(page).to have_css('.requirement-card--unsatisfiable')
      expect(page).to have_text('Evidence impossible to satisfy')
    end

    # RG3: a line asking a question may yet be resolved.
    it 'is no dead end where one type asks a question' do
      wording = card_wording(lines: [line, line(nameable?: false, asking?: true, evidence_type_uuid: 'cccc')])

      render_inline(described_class.new(wording:, country_code: 'EL', countries: [['🇬🇷 EL', 'EL']]))

      expect(page).to have_no_css('.requirement-card--unsatisfiable')
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
      unsatisfied = card_wording(lines: [], published_nothing?: true, combination_id: nil)

      render_inline(described_class.new(wording: unsatisfied, country_code: 'FI', country_name: 'Finland',
        countries: [['🇫🇮 Finland (FI)', 'FI']]))

      expect(page.find('.fr-card__desc').text.squish).to eq('Evidence impossible to satisfy by 🇫🇮 Finland (FI)')
      expect(page).to have_css('.requirement-card--unsatisfiable')
      expect(page.find('.requirement-card__actions').text.squish).to eq('⚠️No provider listed by Finland for this evidence')
    end
  end

  # OOTS-269: the questions the Data Service Directory asks before it can name
  # the provider, chapter 3.1.4 §4.4.3.3.
  describe 'questions of the Data Service Directory' do
    let(:asking) do
      card_wording(lines: [
        line(asking?: true, nameable?: false, evidence_type: 'Projectathon test evidence', evidence_type_uuid: 'bbbb'),
        line(evidence_type: 'Simple test evidence', evidence_type_uuid: 'cccc', provider: 'Ministry of Digital Governance'),
      ])
    end
    let(:questions) do
      [
        described_class::Question.new(id: '1254f10f-406e-4f28-b1ba-d107b93fa264', control: :select,
          label: 'Projectathon test case', language: 'EN', options: [%w[TC03 TC03], %w[TC06 TC06]], value: nil),
        described_class::Question.new(id: '6e0c0b8a-8c1c-4a8f-9b0e-2f1f6d0f1a01', control: :radio,
          label: 'Γεννηθήκατε στο εξωτερικό;', language: 'EL', options: nil, value: nil),
        described_class::Question.new(id: '6e0c0b8a-8c1c-4a8f-9b0e-2f1f6d0f1a02', control: :text,
          label: 'Passport number', language: 'EN', options: nil, value: nil),
      ]
    end

    before do
      render_inline(described_class.new(wording: asking, country_code: 'EL', country_name: 'Greece',
        countries: [['🇬🇷 Greece (EL)', 'EL']], questions: { 'bbbb' => questions }))
    end

    # RG3 of OOTS-270: the questions are a line's, posted with its type, and
    # their answer replaces that line's resolution.
    it 'asks them on the line of their type alone, and posts them with it' do
      form = page.find('[data-demo-card-line="bbbb"] form.requirement-card__questions')

      expect(form['action']).to eq("/admin/demo/v2.0/T1/classification_fournisseur?exigence=#{uuid}&type=bbbb")
      expect(form).to have_css("#question-#{uuid}-bbbb-1254f10f-406e-4f28-b1ba-d107b93fa264")
      expect(page).to have_no_css('[data-demo-card-line="cccc"] form')
      expect(said(page.find('[data-demo-card-line="cccc"]'))).to eq('Simple test evidence from Ministry of Digital Governance')
    end

    # CA2: « codelist, string or boolean and Evidence Requesters MUST support
    # all three of these », in the order the exception writes them.
    it 'asks each in the control its type calls for, in the order given' do
      controls = page.all('form.requirement-card__questions [data-demo-card-question]').map do |group|
        group.all('select, input', visible: :all).map { |field| field.tag_name == 'select' ? 'select' : field[:type] }.uniq
      end

      expect(controls).to eq([%w[select], %w[radio], %w[text]])
      expect(page.all('form.requirement-card__questions input[type=radio] + label').map { |label| label.text.squish })
        .to eq(%w[Yes No])
    end

    # RGAA 8.7: a question in another language than the page says so.
    it 'declares the language of each question' do
      expect(page.all('form.requirement-card__questions .directory-value').pluck(:lang)).to eq(%w[EN EL EN])
    end

    # Each answer sends as it is given, as a country or a type chosen does.
    it 'opens a list on a prompt, sends each answer as it is given, and offers no button to do it' do
      expect(page.first('form.requirement-card__questions option').text).to eq('Select a value')
      expect(page.all('form.requirement-card__questions select, form.requirement-card__questions input:not([type=hidden])',
        visible: :all).pluck('data-action').uniq).to eq(['change->demo-card#answer'])
      expect(page).to have_no_css('form.requirement-card__questions button')
    end

    # RG1: nothing named, nothing requested, nothing refused, and no dead end.
    it 'names nothing under the questions while they wait for their first answers' do
      expect(page.find('[data-demo-card-line="bbbb"] [data-demo-card-target=resolution]', visible: :all).text.squish)
        .to be_empty
      expect(page).to have_no_css('.requirement-card--unsatisfiable')
    end

    it 'renders, hidden, what it says of an answer that could not be sent' do
      expect(page.find('[data-demo-card-target=answerFailure]', visible: :hidden).text.squish)
        .to start_with('The answer could not be sent: this page could not reach the service.')
    end
  end
end
