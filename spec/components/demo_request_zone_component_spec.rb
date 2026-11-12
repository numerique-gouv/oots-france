require 'rails_helper'

RSpec.describe DemoRequestZoneComponent, type: :component do
  # The pages of the walk live under the line they play, and the addresses a
  # component writes take it from the page being rendered.
  subject(:zone) { zone_of(outcome) }

  around { |example| with_request_url('/admin/demo/v2.0/T1/documents') { example.run } }

  let(:requirement_uuid) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }
  let(:type) { DemoRequestZoneComponent::Type.new(uuid: 'aaaa', name: 'Simple test evidence', language: 'EN') }
  let(:outcome) { DemoOutcomeWording.new(answer:, request:) }
  let(:request) { Demo::Request.new(exchange_id: 'echange-1', conversation_id: 'conversation-1') }
  let(:answer) { Demo::ContractAnswer.new(status: 200, payload:) }
  let(:payload) { { 'statut' => 'sent' } }

  # The zone of a combination of one type: a single block, which says what
  # each block says and no more.
  def zone_of(outcome, failure: nil, requirement_uuid: self.requirement_uuid)
    described_class.new(requirement_uuid:,
      blocks: [DemoRequestComponent.new(outcome:, requirement_uuid:, evidence_type: type, failure:)])
  end

  # Nothing has been clicked yet: the zone is the button and nothing else, and
  # it asks nobody anything until it is.
  context 'without a click behind it' do
    subject(:zone) { zone_of(nil) }

    it 'offers the button, and declares nothing to wait on' do
      render_inline(zone)

      expect(page).to have_button('Demander le document')
      expect(page).to have_css(".demo-request__body[data-polling='false']")
    end

    # Rendered beside the button rather than waited for: the controller shows it
    # the instant the button is clicked, without a word of its own and without a
    # round trip.
    it 'carries the waiting it will show, hidden until then' do
      render_inline(zone)

      expect(page).to have_css('[data-demo-request-target="loading"][hidden]', visible: :hidden,
        text: 'Demande du document en cours')
    end
  end

  context 'when the answer is out' do
    it 'stands in the button\'s place and declares itself waiting' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__body[data-polling="true"][data-outcome="pending"]')
      expect(page).to have_no_button('Demander le document')
      expect(page).to have_text('Demande du document en cours')
    end

    # Rendu tout de même, et seulement caché : le bouton reparaît dès que le
    # serveur rend une zone au repos, et un fragment qui l'aurait omis n'en
    # aurait aucun à montrer. Le navigateur, lui, ne le ramène jamais.
    it 'keeps the button in the fragment, hidden, for a settled zone to show again' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__button[hidden]', visible: :hidden)
      expect(page).to have_button('Demander le document', visible: :hidden)
    end

    # Le contrôleur Stimulus déclare quatre cibles et les montre ou les cache
    # sans jamais les créer : celle qu'un état oublie de rendre est un `show`
    # sans effet, muet — c'est exactement ce qui a échappé à la première passe
    # de revue. `failure` est la seule absente ici, l'attente n'ayant aucun
    # refus à rapporter.
    # Le recours que le navigateur montrera quand il renoncera : un lien vers la
    # page, jamais le bouton — cliquer ouvrirait un second échange pendant que
    # le premier court (chapitre 4.4 §4.1).
    it 'holds a way back to the page, not a second click, for when the browser gives up' do
      render_inline(zone)

      recours = page.find('[data-demo-request-target="disconnected"]', visible: :all)

      expect(recours).to have_link('Rechargez la page', href: '/admin/demo/v2.0/T1/documents', visible: :all)
      expect(recours).to have_no_button('Demander le document', visible: :all)
    end

    it 'renders every target the controller will reach for while it waits' do
      render_inline(zone)

      posees = page.all('[data-demo-request-target]', visible: :all).pluck('data-demo-request-target')

      expect(posees).to contain_exactly('button', 'loading', 'disconnected')
    end
  end

  # Chapter 1 §4.2: the evidence is « made available to the specific procedure
  # end-user that issued the query », and the button has nothing left to ask.
  context 'when the document is in hand' do
    before { allow(request).to receive(:evidence?).and_return(true) }

    it 'offers the document and stops waiting' do
      render_inline(zone)

      expect(page).to have_link('Ouvrir le document',
        href: "/admin/demo/v2.0/T1/justificatif?exigence=#{requirement_uuid}&type=aaaa")
      expect(page).to have_css('.demo-request__body[data-polling="false"]')
      expect(page).to have_no_button('Demander le document')
    end

    # The card above has no other way to learn what became of a click it does
    # not hold: it reads this, and wears the border that says the requirement is
    # satisfied.
    it 'says what became of the click, for the card to read' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__body[data-outcome="delivered"]')
    end

    # The button first and the state to its right, in the markup as on the
    # screen: what the zone is doing is read once one knows what was clicked.
    it 'puts the button before what it says of itself' do
      render_inline(zone)

      expect(page.find('.demo-request__block > *:first-child')).to have_text('Ouvrir le document')
      expect(page.find('.demo-request__block > *:nth-child(2)')).to have_text('Document récupéré avec succès')
    end
  end

  # Chapter 2.1 §3.3 has the user told that the evidence cannot be provided, and
  # chapter 4.4 §4.1 makes asking again a new request rather than a retry of the
  # old one — hence a button, under a label saying as much.
  context 'when the correspondent refused' do
    let(:payload) { { 'statut' => 'failed', 'codeErreur' => 'EDM:ERR:0003' } }

    it 'says so with the code received, and offers to ask again' do
      render_inline(zone)

      expect(page).to have_text('Le document ne peut pas être fourni')
      expect(page).to have_text('EDM:ERR:0003')
      expect(page).to have_button('Redemander le document')
      expect(page).to have_css('.demo-request__body[data-polling="false"][data-outcome="failed"]')
    end
  end

  # Chapter 4.10 §4.2, informative: a failure no administration decided is
  # said as OOTS being unavailable, with no code and the same button.
  context 'when the request failed for technical reasons' do
    let(:payload) { { 'statut' => 'failed' } }

    it 'says OOTS is not available, and offers to ask again' do
      render_inline(zone)

      expect(page).to have_css('.fr-alert--error', text: "OOTS n'est pas disponible")
      expect(page).to have_no_text('EDM:ERR')
      expect(page).to have_no_text('Le document ne peut pas être fourni')
      expect(page).to have_button('Redemander le document')
    end
  end

  # The departure page of chapter 4.9 §5, built from what the confirmation
  # handed back and kept on the request.
  context 'when the user has the preview space to visit' do
    before do
      request.assign_attributes(preview_address: 'https://ap.example/preview?t=1', preview_method: 'GET',
        preview_descriptions: [{ 'language' => 'EN', 'text' => 'Your study grant certificate' }])
    end

    it 'presents the link' do
      render_inline(zone)

      expect(page).to have_text("Votre document attend votre accord à l'étranger")
      expect(page).to have_link('Prévisualiser et approuver le document', href: 'https://ap.example/preview?t=1')
    end

    # Chapter 4.9 §5: « Process the language specific information of the
    # preview location description metadata ».
    it 'shows the description the correspondent wrote, in its language, and nothing of its own' do
      render_inline(zone)

      expect(page).to have_css('[lang="EN"]', text: 'Your study grant certificate')
      expect(page).to have_no_text('Vous serez redirigé vers son propre espace')
    end

    # Chapter 4.9 §5: the launch page « customized to the user's language
    # choice (if known) ».
    context 'when the correspondent described it in English and in French' do
      before do
        request.preview_descriptions = [{ 'language' => 'EN', 'text' => 'Your study grant certificate' },
                                        { 'language' => 'FR', 'text' => 'Votre attestation de bourse' }]
      end

      it 'shows the variant in the language of the page' do
        render_inline(zone)

        expect(page).to have_css('[lang="FR"]', text: 'Votre attestation de bourse')
        expect(page).to have_no_text('Your study grant certificate')
      end

      it 'shows the English variant on a page read in English' do
        I18n.with_locale(:en) { render_inline(zone) }

        expect(page).to have_css('[lang="EN"]', text: 'Your study grant certificate')
        expect(page).to have_no_text('Votre attestation de bourse')
      end
    end

    it 'shows the only variant published, under its language, when neither the page\'s nor English is' do
      request.preview_descriptions = [{ 'language' => 'DE', 'text' => 'Ihre Bescheinigung' }]
      render_inline(zone)

      expect(page).to have_css('[lang="DE"]', text: 'Ihre Bescheinigung')
    end

    # Implementing regulation 2022/1463, article 11(2)(b): the user is told
    # they will be redirected, by the procedure where the correspondent said nothing.
    it 'says where the user is going when the correspondent wrote no description' do
      request.preview_descriptions = []
      render_inline(zone)

      expect(page).to have_text('Vous serez redirigé vers son propre espace')
    end

    # The second exchange may settle while the user is away: the zone keeps
    # asking, and offers no button meanwhile.
    it 'keeps asking, and offers nothing to click again' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__body[data-polling="true"][data-outcome="preview"]')
      expect(page).to have_no_button('Demander le document', visible: :all)
    end

    context 'when the correspondent asked for a POST' do
      before do
        request.assign_attributes(preview_method: 'POST',
          preview_body: 'returnurl=https%3A%2F%2Ffr.example%2Fretour%2Fx&returnmethod=GET')
      end

      it 'presents a form posting the fields of the body to the address' do
        render_inline(zone)

        form = page.find('form.demo-request__departure')
        expect(form['action']).to eq('https://ap.example/preview?t=1')
        expect(form['method']).to eq('post')
        expect(form).to have_field('returnurl', type: :hidden, with: 'https://fr.example/retour/x')
        expect(form).to have_field('returnmethod', type: :hidden, with: 'GET')
        expect(form).to have_no_field('authenticity_token', type: :hidden)
        expect(form).to have_button('Prévisualiser et approuver le document')
      end
    end

    context 'when the correspondent asked for a PUT' do
      before { request.preview_method = 'PUT' }

      it 'says the link cannot be presented, and offers to ask again' do
        render_inline(zone)

        expect(page).to have_text('Le lien de prévisualisation ne peut pas être présenté')
        expect(page).to have_no_link('Prévisualiser et approuver le document')
        expect(page).to have_button('Redemander le document')
      end
    end
  end

  # Chapter 4.9 §1: the user decided not to use the document. Their choice, and
  # not a failure — so an informative alert.
  context 'when the user declined the document' do
    let(:payload) { { 'statut' => 'declined' } }

    it 'says so, and offers to ask again' do
      render_inline(zone)

      expect(page).to have_css('.fr-alert--info', text: "Aucun document n'a été envoyé à cette démarche")
      expect(page).to have_button('Redemander le document')
      expect(page).to have_css('.demo-request__body[data-polling="false"][data-outcome="failed"]')
    end
  end

  # Chapter 4.4 §3.3.2: the Unavailable Response, which the portal must tell
  # the user of. Nobody's failure, so an informative alert.
  context 'when the provider announced the document for later' do
    let(:payload) { { 'statut' => 'deferred', 'dateDisponibilite' => '2026-10-23T14:05:00+02:00' } }

    it 'says so with the date announced, and offers to ask again' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__failure .fr-alert--info', text: 'Document annoncé pour plus tard')
      expect(page).to have_text("elle l'a annoncé pour le 23 octobre 2026 à 14:05 (UTC+02:00). Redemandez à partir de cette date")
      expect(page).to have_button('Redemander le document')
      expect(page).to have_css('.demo-request__body[data-polling="false"][data-outcome="failed"]')
      expect(page).to have_css('[data-demo-request-target="loading"][hidden]', visible: :hidden)
    end

    it 'writes the month of the date in the language of the page' do
      I18n.with_locale(:en) { render_inline(zone) }

      expect(page).to have_text('it announced it for October 23, 2026 at 14:05 (UTC+02:00)')
    end

    # Chapter 4.5.2 §2.1: a response, never an `rs:Exception`.
    it 'names no error code, whatever the state carries' do
      payload['codeErreur'] = 'EDM:ERR:0003'
      render_inline(zone)

      expect(page).to have_no_text('EDM:ERR')
    end

    it 'says it without a date when none was announced' do
      payload.delete('dateDisponibilite')
      render_inline(zone)

      expect(page).to have_text("elle l'a annoncé pour plus tard, sans dire quand")
    end

    # The screen's deadline is for a wait, and this is an answer.
    it 'says the same an hour later' do
      request.created_at = Time.current
      render_inline(zone_of(DemoOutcomeWording.new(answer:, request:, clock: instance_double(Clock, now: 1.hour.from_now))))

      expect(page).to have_text('Document annoncé pour plus tard')
      expect(page).to have_no_text('Pas encore de réponse')
    end
  end

  context 'when the confirmation of the preview failed' do
    let(:payload) { { 'statut' => 'preview_required' } }
    let(:outcome) do
      DemoOutcomeWording.new(answer:, request:, unconfirmed: { key: :demo_preview_unconfirmed, errors: ['refusée'] })
    end

    # What the contract said is written for the operator, in French: it stays in
    # the log, and the user reads a sentence of the portal's own.
    it 'says so in a sentence of its own, never the contract\'s, and offers to ask again' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__failure .fr-alert--error',
        text: 'La prévisualisation a échoué')
      expect(page).to have_text("La prévisualisation de votre document n'a pas pu démarrer")
      expect(page).to have_no_text('refusée')
      expect(page).to have_button('Redemander le document')
    end
  end

  # The deadline is the screen's and not the exchange's: the exchange carries on
  # and the register keeps it, so the wording says the request is still on its
  # way rather than that it failed.
  context 'when this screen has waited long enough' do
    let(:outcome) do
      DemoOutcomeWording.new(answer:, request:, clock: instance_double(Clock, now: 1.hour.from_now))
    end

    before { request.created_at = Time.current }

    it 'stops waiting and offers to ask again' do
      render_inline(zone)

      expect(page).to have_text("n'a pas encore répondu")
      expect(page).to have_button('Redemander le document')
      expect(page).to have_css('.demo-request__body[data-polling="false"]')
    end
  end

  # The contract unreachable says nothing of the exchange: the zone reports the
  # outage rather than presenting it as an answer.
  context 'when the contract could not be read' do
    subject(:zone) { zone_of(DemoOutcomeWording.unanswered(request:, error: 'Panne')) }

    it 'reports the outage where it would report a refusal, and keeps its reason for the log' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__failure', text: "L'état de la demande n'a pas pu être lu")
      expect(page).to have_no_text('Panne')
    end
  end

  # A click refused before an exchange existed leaves the session on the exchange
  # of the journey before, whose code says nothing of what just happened.
  context 'when the click was refused while an earlier exchange is still followed' do
    subject(:zone) do
      zone_of(outcome, failure: { key: :demo_refused, errors: ['EB:ERR:0001'] })
    end

    let(:payload) { { 'statut' => 'failed', 'codeErreur' => 'EDM:ERR:0003' } }

    it 'shows no code at all rather than the one the earlier exchange returned' do
      render_inline(zone)

      expect(page).to have_text('EB:ERR:0001')
      expect(page).to have_no_text('EDM:ERR:0003')
    end

    # Asking again is what an announcement invites: a refusal of that click is
    # said as a refusal, never under the announcement it replaces.
    context 'when the earlier exchange was announced for later' do
      let(:payload) { { 'statut' => 'deferred', 'dateDisponibilite' => '2026-10-23T14:05:00+02:00' } }

      it 'says the refusal, as an error' do
        render_inline(zone)

        expect(page).to have_css('.fr-alert--error', text: 'EB:ERR:0001')
        expect(page).to have_no_text('Document annoncé pour plus tard')
      end
    end
  end

  # A refusal pronounced before any exchange existed: there is nothing to follow,
  # and the zone names which of the contract's refusals it was.
  context 'when the click itself was refused' do
    subject(:zone) do
      zone_of(nil, failure: { key: :demo_refused, errors: ['EB:ERR:0001'] })
    end

    it 'names the refusal and what the contract returned' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__failure', text: 'refusée')
      expect(page).to have_no_css('.demo-request__failure[lang]')
      expect(page).to have_text('EB:ERR:0001')
      expect(page).to have_button('Redemander le document')
    end

    # CA6: the title follows the page, the contract's words stay as received.
    it 'titles the refusal in English on a page read in English, the message untouched' do
      I18n.with_locale(:en) { render_inline(zone) }

      expect(page).to have_css('.demo-request__failure', text: I18n.t('interactors.failures.demo_refused', locale: :en))
      expect(page).to have_no_css('.demo-request__failure[lang]')
      expect(page).to have_text('EB:ERR:0001')
    end
  end

  # A page carries one zone per requirement it can name, and nothing but the
  # address tells them apart: a click that named no requirement would ask the
  # contract for whichever one it publishes first, under another card's name.
  describe 'the requirement each zone is about' do
    subject(:zone) { zone_of(nil, requirement_uuid: '2d21a531-d30e-4e30-9e5e-b53d6aedb30b') }

    it 'names it, and the type of the block, on the address the button posts to' do
      render_inline(zone)

      expect(page).to have_css(
        "form.demo-request__button[action='/admin/demo/v2.0/T1/demande?exigence=2d21a531-d30e-4e30-9e5e-b53d6aedb30b&type=aaaa']",
        visible: :all,
      )
    end

    it 'names no type in a block alone' do
      render_inline(zone)

      expect(page).to have_no_css('.demo-request__type')
    end
  end

  # OOTS-270: a combination of several types, a block per type.
  describe 'a combination of several types' do
    let(:types) do
      [DemoRequestZoneComponent::Type.new(uuid: 'bbbb', name: 'Projectathon test evidence', language: 'EN'),
       DemoRequestZoneComponent::Type.new(uuid: 'cccc', name: 'Simple test evidence', language: 'EN')]
    end

    def blocks(outcomes, failures: {})
      types.zip(outcomes).map do |each, outcome|
        DemoRequestComponent.new(outcome:, requirement_uuid:, evidence_type: each, headed: true, failure: failures[each.uuid])
      end
    end

    # CA2 and CA3: one button, which asks for them all.
    it 'offers one button for them all while none has been asked for' do
      render_inline(described_class.new(requirement_uuid:, blocks: blocks([nil, nil])))

      expect(page).to have_button('Demander les documents')
      expect(page).to have_css("form.demo-request__button[action='/admin/demo/v2.0/T1/demande?exigence=#{requirement_uuid}']")
      expect(page).to have_css('.demo-request__body[data-polling="false"][data-outcome="idle"]')
      expect(page).to have_css('[data-demo-request-target="loading"]', visible: :hidden, text: 'Demande des documents en cours')
    end

    # CA5: a click the contract refused leaves each type its own button.
    it 'offers each block its own button once the combination was asked for' do
      render_inline(described_class.new(requirement_uuid:, blocks: blocks([nil, nil]), requested: true))

      expect(page.all('[data-demo-request-block] button').map(&:text)).to eq(['Demander le document'] * 2)
    end

    # CA6: a block per demand, each under the name of its type, and the zone
    # waiting while any of them does.
    it 'says each request in its own block, under the name of its type' do
      render_inline(described_class.new(requirement_uuid:, blocks: blocks([outcome, nil])))

      expect(page.all('.demo-request__type').map { |name| name.text.squish })
        .to eq(['Projectathon test evidence, récupéré auprès des services communs',
                'Simple test evidence, récupéré auprès des services communs'])
      expect(page).to have_css('.demo-request__body[data-polling="true"][data-outcome="pending idle"]')
      expect(page).to have_css('[data-demo-request-block][data-state="idle"]', text: 'Demander le document')
    end

    # OOTS-257 CA2: an announced block is settled, and the zone waits on the other.
    it 'keeps waiting on a block still out beside an announced one' do
      deferred = DemoOutcomeWording.new(answer: Demo::ContractAnswer.new(status: 200, payload: { 'statut' => 'deferred' }),
        request:)
      render_inline(described_class.new(requirement_uuid:, blocks: blocks([deferred, outcome])))

      expect(page).to have_css('.demo-request__body[data-polling="true"][data-outcome="failed pending"]')
      expect(page).to have_css('[data-demo-request-block="bbbb"] .fr-alert--info', text: 'Document annoncé pour plus tard')
    end

    # CA5: a click the contract refused is said in the block of its type, and
    # the other keeps its own button.
    it 'says a refused click in the block of its type alone' do
      render_inline(described_class.new(requirement_uuid:,
        blocks: blocks([nil, nil], failures: { 'bbbb' => { key: :demo_refused, errors: ['refus'] } })))

      first, second = page.all('[data-demo-request-block]').to_a
      expect(first).to have_css('.demo-request__failure', text: 'refus')
      expect(second).to have_no_css('.demo-request__failure')
      expect(second).to have_css("form[action='/admin/demo/v2.0/T1/demande?exigence=#{requirement_uuid}&type=cccc']")
    end
  end
end
