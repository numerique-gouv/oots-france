require 'rails_helper'

RSpec.describe DemoRequestZoneComponent, type: :component do
  # The pages of the walk live under the line they play, and the addresses a
  # component writes take it from the page being rendered.
  subject(:zone) { described_class.new(outcome:, requirement_uuid:) }

  around { |example| with_request_url('/admin/demo/v2.0/documents') { example.run } }

  let(:requirement_uuid) { 'ffffffff-ffff-ffff-ffff-ffffffffffff' }

  let(:outcome) { DemoOutcomeWording.new(answer:, request:) }
  let(:request) { Demo::Request.new(exchange_id: 'echange-1', conversation_id: 'conversation-1') }
  let(:answer) { Demo::ContractAnswer.new(status: 200, payload:) }
  let(:payload) { { 'statut' => 'sent' } }

  # Nothing has been clicked yet: the zone is the button and nothing else, and
  # it asks nobody anything until it is.
  context 'without a click behind it' do
    subject(:zone) { described_class.new(outcome: nil, requirement_uuid:) }

    it 'offers the button, and declares nothing to wait on' do
      render_inline(zone)

      expect(page).to have_button('Request the document')
      expect(page).to have_css(".demo-request__body[data-polling='false']")
    end

    # Rendered beside the button rather than waited for: the controller shows it
    # the instant the button is clicked, without a word of its own and without a
    # round trip.
    it 'carries the waiting it will show, hidden until then' do
      render_inline(zone)

      expect(page).to have_css('[data-demo-request-target="loading"][hidden]', visible: :hidden,
        text: 'Requesting the document')
    end
  end

  context 'when the answer is out' do
    it 'stands in the button\'s place and declares itself waiting' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__body[data-polling="true"][data-outcome="pending"]')
      expect(page).to have_no_button('Request the document')
      expect(page).to have_text('Requesting the document')
    end

    # Rendu tout de même, et seulement caché : le bouton reparaît dès que le
    # serveur rend une zone au repos, et un fragment qui l'aurait omis n'en
    # aurait aucun à montrer. Le navigateur, lui, ne le ramène jamais.
    it 'keeps the button in the fragment, hidden, for a settled zone to show again' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__button[hidden]', visible: :hidden)
      expect(page).to have_button('Request the document', visible: :hidden)
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

      expect(recours).to have_link('Reload the page', href: '/admin/demo/v2.0/documents', visible: :all)
      expect(recours).to have_no_button('Request the document', visible: :all)
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

      expect(page).to have_link('Open the document',
        href: "/admin/demo/v2.0/justificatif?exigence=#{requirement_uuid}")
      expect(page).to have_css('.demo-request__body[data-polling="false"]')
      expect(page).to have_no_button('Request the document')
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

      expect(page.find('.demo-request__body > *:first-child')).to have_text('Open the document')
      expect(page.find('.demo-request__body > *:nth-child(2)')).to have_text('Document retrieved successfully')
    end
  end

  # Chapter 2.1 §3.3 has the user told that the evidence cannot be provided, and
  # chapter 4.4 §4.1 makes asking again a new request rather than a retry of the
  # old one — hence a button, under a label saying as much.
  context 'when the correspondent refused' do
    let(:payload) { { 'statut' => 'failed', 'codeErreur' => 'EDM:ERR:0003' } }

    it 'says so with the code received, and offers to ask again' do
      render_inline(zone)

      expect(page).to have_text('The document cannot be provided')
      expect(page).to have_text('EDM:ERR:0003')
      expect(page).to have_button('Retry to request')
      expect(page).to have_css('.demo-request__body[data-polling="false"][data-outcome="failed"]')
    end
  end

  # The departure page of chapter 4.9 §5, built from what the confirmation
  # handed back and kept on the request.
  context 'when the user has the preview space to visit' do
    before do
      request.assign_attributes(preview_address: 'https://ap.example/preview?t=1', preview_method: 'GET',
        preview_description: 'Your study grant certificate', preview_description_language: 'EN')
    end

    it 'says where the user is going, and presents the link' do
      render_inline(zone)

      expect(page).to have_text('Your document is waiting for your approval abroad')
      expect(page).to have_text('You will be redirected to its own space')
      expect(page).to have_link('Preview and approve the document', href: 'https://ap.example/preview?t=1')
    end

    # Chapter 4.9 §5: « Process the language specific information of the
    # preview location description metadata ».
    it 'shows the description the correspondent wrote, in its language' do
      render_inline(zone)

      expect(page).to have_css('[lang="EN"]', text: 'Your study grant certificate')
    end

    # The second exchange may settle while the user is away: the zone keeps
    # asking, and offers no button meanwhile.
    it 'keeps asking, and offers nothing to click again' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__body[data-polling="true"][data-outcome="preview"]')
      expect(page).to have_no_button('Request the document', visible: :all)
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
        expect(form).to have_button('Preview and approve the document')
      end
    end

    context 'when the correspondent asked for a PUT' do
      before { request.preview_method = 'PUT' }

      it 'says the link cannot be presented, and offers to ask again' do
        render_inline(zone)

        expect(page).to have_text('The preview link cannot be presented')
        expect(page).to have_no_link('Preview and approve the document')
        expect(page).to have_button('Retry to request')
      end
    end
  end

  # Chapter 4.9 §1: the user decided not to use the document. Their choice, and
  # not a failure — so an informative alert.
  context 'when the user declined the document' do
    let(:payload) { { 'statut' => 'declined' } }

    it 'says so, and offers to ask again' do
      render_inline(zone)

      expect(page).to have_css('.fr-alert--info', text: 'You chose not to use this document')
      expect(page).to have_button('Retry to request')
      expect(page).to have_css('.demo-request__body[data-polling="false"][data-outcome="failed"]')
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

      expect(page).to have_css('.demo-request__failure[lang="en"] .fr-alert--error',
        text: 'The preview has failed')
      expect(page).to have_text('The preview of your document could not be started')
      expect(page).to have_no_text('refusée')
      expect(page).to have_button('Retry to request')
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

      expect(page).to have_text('has not answered yet')
      expect(page).to have_button('Retry to request')
      expect(page).to have_css('.demo-request__body[data-polling="false"]')
    end
  end

  # The contract unreachable says nothing of the exchange: the zone reports the
  # outage rather than presenting it as an answer.
  context 'when the contract could not be read' do
    subject(:zone) { described_class.new(outcome: DemoOutcomeWording.unanswered(request:, error: 'Panne'), requirement_uuid:) }

    it 'reports the outage where it would report a refusal, and keeps its reason for the log' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__failure[lang="en"]', text: 'could not be read')
      expect(page).to have_no_text('Panne')
    end
  end

  # A click refused before an exchange existed leaves the session on the exchange
  # of the journey before, whose code says nothing of what just happened.
  context 'when the click was refused while an earlier exchange is still followed' do
    subject(:zone) do
      described_class.new(outcome:, requirement_uuid:, failure: { key: :demo_refused, errors: ['EB:ERR:0001'] })
    end

    let(:payload) { { 'statut' => 'failed', 'codeErreur' => 'EDM:ERR:0003' } }

    it 'shows no code at all rather than the one the earlier exchange returned' do
      render_inline(zone)

      expect(page).to have_text('EB:ERR:0001')
      expect(page).to have_no_text('EDM:ERR:0003')
    end
  end

  # A refusal pronounced before any exchange existed: there is nothing to follow,
  # and the zone names which of the contract's refusals it was.
  context 'when the click itself was refused' do
    subject(:zone) do
      described_class.new(outcome: nil, requirement_uuid:, failure: { key: :demo_refused, errors: ['EB:ERR:0001'] })
    end

    it 'names the refusal and what the contract returned' do
      render_inline(zone)

      expect(page).to have_css('.demo-request__failure[lang="fr"]', text: 'refusée')
      expect(page).to have_text('EB:ERR:0001')
      expect(page).to have_button('Retry to request')
    end
  end

  # A page carries one zone per requirement it can name, and nothing but the
  # address tells them apart: a click that named no requirement would ask the
  # contract for whichever one it publishes first, under another card's name.
  describe 'the requirement each zone is about' do
    subject(:zone) { described_class.new(outcome: nil, requirement_uuid: '2d21a531-d30e-4e30-9e5e-b53d6aedb30b') }

    it 'names it on the address the button posts to' do
      render_inline(zone)

      expect(page).to have_css(
        "form.demo-request__button[action='/admin/demo/v2.0/demande?exigence=2d21a531-d30e-4e30-9e5e-b53d6aedb30b']",
        visible: :all,
      )
    end
  end
end
