require 'rails_helper'

RSpec.describe 'AvailableEvidence' do
  let(:page) { response.parsed_body }
  let(:requirement_uuid) { DirectorySnapshots::REQUIREMENT.split('/').last }
  let(:empty_requirement_uuid) { DirectorySnapshots::EMPTY_REQUIREMENT.split('/').last }
  let(:directories) { /oots\.tech\.ec\.europa\.eu/ }

  before do
    stub_code_list(
      countries: { 'AT' => 'Autriche (l’)', 'EL' => 'Grèce (la)', 'FI' => 'Finlande (la)', 'FR' => 'France (la)' },
      country_names: { 'AT' => 'Austria', 'EL' => 'Greece', 'FI' => 'Finland', 'FR' => 'France' },
    )
  end

  def rows_of(country)
    page.css('#detail-par-pays tbody').find { |group| group.at_css('th').text.squish.end_with?(country) }
  end

  describe 'GET /justificatifs_disponibles' do
    # CA11
    context 'without any copy taken' do
      it 'answers 404 on the page of a requirement' do
        get available_evidence_path(requirement_uuid)

        expect(response).to have_http_status(:not_found)
      end

      it 'says in an alert that the data is not available yet, and lists nothing' do
        get available_evidence_index_path

        expect(response).to have_http_status(:ok)
        expect(page.at_css('.fr-alert').text.squish).to eq('Les données des annuaires ne sont pas encore disponibles.')
        expect(page.css('main a[href^="/justificatifs_disponibles/"]')).to be_empty
        expect(page.at_css('main').text).not_to include('Données des annuaires de production au')
      end
    end

    context 'with a copy taken' do
      before { take_snapshot }

      # CA1, CA6, CA7
      it 'offers every requirement of the copy as a card, in alphabetical order, without a form' do
        get available_evidence_index_path

        expect(response).to have_http_status(:ok)
        expect(page.css('#liste-exigences .fr-card__title a').map { [it.text.squish, it['href']] }).to eq([
          ['(TEST) Test Requirement', available_evidence_path(requirement_uuid)],
          ['(TEST) Test Requirement 2', available_evidence_path(empty_requirement_uuid)],
        ])
        expect(page.at_css('input[type=search]')['data-filter-entries-value']).to eq('#liste-exigences > *')
        expect(page.css('form')).to be_empty
        expect(page.at_css('main').text).to include('Données des annuaires de production au 8 novembre 2026')
        expect(a_request(:any, directories)).not_to have_been_made
      end

      it 'names on each card the countries publishing for the requirement, or that none does' do
        get available_evidence_index_path

        first, second = page.css('#liste-exigences .fr-card')
        expect(first.at_css('.fr-card__footer').text.squish)
          .to include('Justificatifs publiés par', 'Autriche', 'Finlande', 'Grèce')
        expect(first.at_css('.fr-card__footer').text).not_to include('France')
        expect(second.at_css('.fr-card__footer').text.squish)
          .to include('Aucun pays ne publie de justificatif pour cette exigence.')
      end

      # The whole card, footer included, leads to the requirement: its
      # countries are plain tags.
      it 'makes the whole card one link to the requirement' do
        get available_evidence_index_path

        card = page.at_css('#liste-exigences .fr-card')
        expect(card['class']).to include('fr-enlarge-link', 'card--whole')
        expect(card.css('a').pluck('href')).to eq([available_evidence_path(requirement_uuid)])
      end

      # RG15: a list of the countries publishing, which narrows the cards
      # together with the search, in the browser.
      it 'offers to narrow the cards to a publishing country' do
        get available_evidence_index_path

        choice = page.at_css('select#filtre-pays')
        expect(choice.css('option').map { [it.text, it['value']] }).to eq([
          ['Tous les pays', ''], ['🇦🇹 Autriche (AT)', 'AT'], ['🇫🇮 Finlande (FI)', 'FI'], ['🇬🇷 Grèce (EL)', 'EL'],
        ])
        expect(page.at_css('input[type=search]')['data-filter-choice-value']).to eq('#filtre-pays')
        expect(page.css('#liste-exigences > div').pluck('data-filter-keys')).to eq(['AT EL FI', ''])
        expect(page.css('main form')).to be_empty
      end

      # CA12
      it 'hangs from the front page, and carries its menu' do
        get available_evidence_index_path

        expect(page.css('.fr-breadcrumb a').map { [it.text.squish, it['href']] })
          .to eq([['Accueil', root_path], ['Justificatifs disponibles', nil]])
        expect(page.css('nav.fr-nav a').map { [it['href'], it.text.squish] }).to eq([
          ['/#comprendre', 'OOTS en bref'], ['/#fonctionnement', 'Comment ça marche'],
          ['/#concerne', 'Êtes-vous concerné ?'], [available_evidence_index_path, 'Justificatifs disponibles'],
          ['/#raccorder', 'Se raccorder'], ['/#faq', 'Questions fréquentes'],
        ])
      end

      # CA6
      it 'shows no form to an admitted agent nobody named administrator' do
        sign_in
        get available_evidence_index_path

        expect(page.css('main form')).to be_empty
        expect(page.at_css('main').text).not_to include('Mettre à jour')
      end
    end

    # CA9, CA10
    context 'when the administrator reads it' do
      before { sign_in_as_administrator }

      it 'carries the button on the line of the date of the last success, without an alert' do
        take_snapshot
        get available_evidence_index_path

        line = page.at_css('#mise-a-jour')
        expect(line.at_css("form[action='#{available_evidence_refresh_path}'] button").text.squish).to eq('Mettre à jour')
        expect(line.text.squish).to include('Données des annuaires de production au 8 novembre 2026')
        expect(page.css('#echec-mise-a-jour, .fr-callout')).to be_empty
      end

      it 'says when the last attempt failed on an unreachable directory, and why' do
        take_snapshot
        DirectorySnapshot.record_failure!(code: nil, detail: 'Délai dépassé', failed_at: Time.zone.local(2026, 11, 9, 2, 43))
        get available_evidence_index_path

        expect(page.at_css('#mise-a-jour').text.squish).to include('Données des annuaires de production au 8 novembre 2026')
        expect(page.at_css('#echec-mise-a-jour').text.squish).to include(
          'Dernière tentative échouée le 9 novembre 2026, sans code de refus d\'un annuaire : injoignable', 'Délai dépassé'
        )
      end

      # The first copy is taken by this button.
      it 'carries the button before any copy was taken' do
        get available_evidence_index_path

        expect(page.at_css("#mise-a-jour form[action='#{available_evidence_refresh_path}']")).to be_present
        expect(page.at_css('.fr-alert').text.squish).to eq('Les données des annuaires ne sont pas encore disponibles.')
      end

      it 'names the code a directory refused with' do
        DirectorySnapshot.record_failure!(code: 'DSD:ERR:0003', detail: 'refus',
          failed_at: Time.zone.local(2026, 11, 9, 2, 43))
        get available_evidence_index_path

        expect(page.at_css('#mise-a-jour').text.squish).to include("Aucune mise à jour n'a encore réussi.")
        expect(page.at_css('#echec-mise-a-jour').text.squish).to include("Dernière tentative échouée le 9 novembre 2026 : un annuaire l'a refusée, code DSD:ERR:0003.")
      end
    end

    # CA10, CA11
    it 'shows a visitor the copy and its date, and nothing of a failure since' do
      take_snapshot
      DirectorySnapshot.record_failure!(code: nil, detail: 'Délai dépassé', failed_at: Time.zone.local(2026, 11, 9, 2, 43))

      get available_evidence_index_path

      expect(page.at_css('main').text).to include('Données des annuaires de production au 8 novembre 2026')
      expect(page.at_css('main').text).not_to include('échouée', 'injoignable', 'Délai dépassé')
      expect(page.css('#echec-mise-a-jour, form')).to be_empty
    end

    # CA13
    it 'keeps the name the directory publishes on the English page' do
      take_snapshot
      get available_evidence_index_path(locale: 'en')
      follow_redirect!

      expect(page.at_css('h1').text).to eq('Evidence available through OOTS')
      expect(page.css('#liste-exigences .fr-card__title a').map { it.text.squish }).to include('(TEST) Test Requirement')
      expect(page.at_css('main').text).to include('Data of the production directories as of')
    end
  end

  # RG16: the two smoke-test requirements of the production directories, under
  # the nil and the max UUID, are not shown; the evidence types titled « test »
  # elsewhere are.
  context 'with the smoke tests of the directories in the copy' do
    before { take_snapshot(smoke_tests: true) }

    it 'lists neither of the two requirements' do
      get available_evidence_index_path

      expect(page.css('#liste-exigences .fr-card')).to be_empty
      expect(page.at_css('#aucune-exigence')['hidden']).to be_nil
    end

    it 'answers 404 for a smoke-test requirement' do
      get available_evidence_path('00000000-0000-0000-0000-000000000000')

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /justificatifs_disponibles/:requirement_id' do
    before { take_snapshot }

    # CA2, CA4, CA6
    it 'details country by country what the directories publish, without asking them' do
      get available_evidence_path(requirement_uuid)

      expect(response).to have_http_status(:ok)
      expect(page.css('#detail-par-pays tbody th').map { it.text.squish })
        .to eq(['🇦🇹 Autriche', '🇫🇮 Finlande', '🇫🇷 France', '🇬🇷 Grèce'])
      expect(page.at_css('#detail-par-pays tbody th span')['aria-hidden']).to eq('true')
      expect(page.css('form')).to be_empty
      expect(a_request(:any, directories)).not_to have_been_made
      expect(page.at_css('main').text).not_to include('Publié', 'Brouillon', 'En revue', 'Mise en service prévue')
    end

    # CA2: every format of every distribution, and the titles in each language.
    it 'names the publisher and every format of the data services' do
      get available_evidence_path(requirement_uuid)

      austria = rows_of('Autriche')
      row = austria.css('tr').find { it.text.include?('Test Evidence Austria (AT)') }
      expect(row.text).to include('Test Nachweisart Österreich (AT)', 'Test Evidence Provider Austria (AT)')
      expect(row.css('abbr').map { [it.text, it['title']] })
        .to eq([%w[JSON application/json], %w[XML application/xml], %w[PDF application/pdf]])
      expect(row.at_css('.fr-badge--success').text).to eq('En service')
    end

    # CA2: the lists of one country are alternatives, the types of one list required together.
    # A combination of one type says nothing a reader needs: the sentence is
    # kept for two types and more.
    it 'announces a combination of several evidence types, and only those' do
      get available_evidence_path(requirement_uuid)

      announced = rows_of('Grèce').css('td').select { it.text.include?('exigée d\'un bloc') }
      expect(announced.map { it.text.squish }).to eq(["Combinaison Compound test evidence, exigée d'un bloc"])
      expect(rows_of('Grèce').at_css('th')['rowspan']).to eq('5')
      expect(rows_of('Finlande').text).not_to include('Combinaison')
    end

    # CA2: what the Data Service Directory refuses is said on the line of the country.
    it 'says each refusal of the Data Service Directory, and each NoMatch, without an alert' do
      get available_evidence_path(requirement_uuid)

      expect(rows_of('Finlande').text.squish)
        .to include('Aucun data service inscrit pour ce justificatif (DSD:ERR:0001).', 'Non inscrit')
      expect(rows_of('Grèce').text.squish).to include('demande une précision sur l\'usager', 'DSD:ERR:0005')
      expect(rows_of('France').text.squish)
        .to include('Ce pays déclare ne délivrer aucun justificatif pour cette exigence.', 'No such evidence in France')
      expect(page.css('.fr-alert')).to be_empty
    end

    it 'says a type the Data Service Directory does not know' do
      DirectorySnapshot.delete_all
      take_snapshot(data_services: { '19f0783e' => unknown_evidence_type_answer })
      get available_evidence_path(requirement_uuid)

      expect(rows_of('Finlande').text.squish).to include('ne connaît pas ce justificatif (DSD:ERR:0002)')
    end

    # CA3: Greece counts by its `DSD:ERR:0005`, Finland not by its `DSD:ERR:0001`, France not by its NoMatch.
    it 'counts the evidence types and the countries, and names those in service' do
      get available_evidence_path(requirement_uuid)

      text = page.at_css('main').text.squish
      expect(text).to include('5 types de justificatif référencés par 3 pays pour cette exigence.',
        'En service 4 types de justificatif, dans 2 pays : Autriche et Grèce.')
    end

    # CA2, CA3
    it 'says the Evidence Broker publishes nothing, and counts nothing' do
      get available_evidence_path(empty_requirement_uuid)

      expect(response).to have_http_status(:ok)
      expect(page.at_css('main').text.squish).to include('aucun justificatif pour cette exigence (EB:ERR:0001)')
      expect(page.css('#detail-par-pays')).to be_empty
      expect(page.css('.fr-alert')).to be_empty
    end

    it 'ends on the way to the team' do
      get available_evidence_path(requirement_uuid)

      expect(page.at_css('#titre-suite').text).to eq('Votre démarche demande ce justificatif ?')
      expect(page.css('a.fr-btn').pluck('href')).to include(ApplicationHelper::TEAM_MAIL_ADDRESS, root_path)
    end

    # CA12
    it 'hangs from the page of available evidence' do
      get available_evidence_path(requirement_uuid)

      expect(page.css('.fr-breadcrumb a').map { [it.text.squish, it['href']] }).to eq([
        ['Accueil', root_path], ['Justificatifs disponibles', available_evidence_index_path],
        ['(TEST) Test Requirement', nil],
      ])
    end

    it 'answers 404 for a requirement the copy does not hold' do
      get available_evidence_path('11111111-1111-1111-1111-111111111111')

      expect(response).to have_http_status(:not_found)
    end
  end

  # CA5, RG5: the deployment exchanges in acceptance through a proxy; the
  # pages show the production copy all the same, and ask no directory.
  context 'when the deployment exchanges in acceptance' do
    before do
      allow(Settings).to receive_messages(common_services_environment: 'acc')
      allow(Settings).to receive(:common_services_base_url).and_return('https://mandataire.example')
      serve_production_directories
      DirectorySnapshotting::Take.call
      WebMock::RequestRegistry.instance.reset!
    end

    it 'shows the copy taken from production, and asks neither environment' do
      get available_evidence_index_path
      get available_evidence_path(requirement_uuid)

      expect(response).to have_http_status(:ok)
      expect(page.css('#detail-par-pays tbody th').size).to eq(4)
      expect(a_request(:any, directories)).not_to have_been_made
      expect(a_request(:any, /mandataire/)).not_to have_been_made
    end
  end

  describe 'POST /justificatifs_disponibles/mise_a_jour' do
    # CA9
    it 'refuses a visitor without a session, and enqueues nothing' do
      expect { post available_evidence_refresh_path }.not_to have_enqueued_job(RefreshDirectorySnapshotJob)

      expect(response).to have_http_status(:forbidden)
      expect(a_request(:any, directories)).not_to have_been_made
    end

    it 'refuses an admitted agent nobody named administrator' do
      sign_in

      expect { post available_evidence_refresh_path }.not_to have_enqueued_job(RefreshDirectorySnapshotJob)
      expect(response).to have_http_status(:forbidden)
    end

    it 'launches the update for the administrator, and says so' do
      sign_in_as_administrator

      expect { post available_evidence_refresh_path }.to have_enqueued_job(RefreshDirectorySnapshotJob)
      follow_redirect!
      expect(page.at_css('.fr-alert').text.squish).to include('La mise à jour de la copie des annuaires est lancée.')
    end

    # GoodJob alone enforces the limit, so the adapter is GoodJob's for this one.
    it 'starts no second update while one is waiting or running' do
      sign_in_as_administrator
      adapter = RefreshDirectorySnapshotJob.queue_adapter
      RefreshDirectorySnapshotJob.queue_adapter = GoodJob::Adapter.new(execution_mode: :external)

      post available_evidence_refresh_path
      expect { post available_evidence_refresh_path }.not_to change(GoodJob::Job, :count).from(1)
      follow_redirect!
      expect(page.at_css('.fr-alert').text.squish).to include('Une mise à jour de la copie des annuaires est déjà en cours.')
    ensure
      RefreshDirectorySnapshotJob.queue_adapter = adapter
    end
  end
end
