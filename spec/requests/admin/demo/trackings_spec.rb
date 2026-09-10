require 'rails_helper'

RSpec.describe 'Admin::Demo::Trackings' do
  before do
    sign_in
    identify_demo_user
    stub_oots_france_public_keys
    stub_evidence_request
  end

  # The journey rather than a session written by hand: chapter 1 §4.2 makes the
  # evidence available to « the specific procedure end-user that issued the
  # query », and issuing the query is what puts the exchange in the session and
  # the request in the register. An example that posed both would be proving
  # them against itself.
  def confirm_the_request = post admin_demo_confirmation_path

  def reset_session_identity
    allow(Demo::UserIdentity).to receive(:from_session).and_return(nil)
  end

  describe 'GET /admin/demo/suivi' do
    # CA4: nothing back yet, and nothing asked of anyone by looking.
    it 'says the request is under way, and opens no exchange by being looked at' do
      confirm_the_request
      stub_exchange_state(statut: 'sent')
      WebMock::RequestRegistry.instance.reset!

      get admin_demo_suivi_path

      expect(response.parsed_body.css('main').text).to include('en cours')
      expect(a_request(:get, "#{Settings.oots_france_url}/requete/pieceJustificative")
        .with(query: hash_including({}))).not_to have_been_made
    end

    # CA1: the evidence is offered to open and to save, and the digest shown is
    # that of the bytes the delivery carried.
    it 'offers the evidence once it has been delivered' do
      confirm_the_request
      Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b)
      stub_exchange_state(statut: 'delivered')

      get admin_demo_suivi_path

      expect(response.parsed_body.css("main a[href='#{admin_demo_suivi_justificatif_path}']")).to be_present
      expect(response.parsed_body.css('main').text)
        .to include(Digest::SHA256.hexdigest("%PDF-1.4\ndrapeau".b))
    end

    # The two writers are two processes with the handover between them:
    # `SettleExchange` marks the exchange delivered only after this procedure has
    # answered the POST, so the document is filed here first.
    it 'shows the evidence in hand even while the contract still says sent' do
      confirm_the_request
      Demo::Request.sole.receive_evidence!("%PDF-1.4\ndrapeau".b)
      stub_exchange_state(statut: 'sent')

      get admin_demo_suivi_path

      expect(response.parsed_body.css("main a[href='#{admin_demo_suivi_justificatif_path}']")).to be_present
    end

    it 'keeps waiting when the contract says delivered and nothing has arrived' do
      confirm_the_request
      stub_exchange_state(statut: 'delivered')

      get admin_demo_suivi_path

      expect(response.parsed_body.css('main').text).to include('en cours')
      expect(response.parsed_body.css("main a[href='#{admin_demo_suivi_justificatif_path}']")).to be_empty
    end

    # CA2. Chapter 2.1 §3.3: « the user MUST receive an automated message
    # explaining that the evidence cannot be provided. » The code beside it is a
    # choice of the demonstration, no chapter asking for it.
    it 'says the evidence cannot be provided, and carries the EDM code' do
      confirm_the_request
      stub_exchange_state(statut: 'failed', codeErreur: 'EDM:ERR:0004')

      get admin_demo_suivi_path

      expect(response.parsed_body.css('main').text)
        .to include('ne peut pas être fourni', 'EDM:ERR:0004')
    end

    # The timeout the sweep declares reads as any other refusal: chapter 4.5.3
    # defines one code for it, and the page gives it no wording of its own.
    it 'reads a timeout as it reads every other refusal' do
      confirm_the_request
      stub_exchange_state(statut: 'failed', codeErreur: 'EDM:ERR:0005')

      get admin_demo_suivi_path

      expect(response.parsed_body.css('main').text)
        .to include('ne peut pas être fourni', 'EDM:ERR:0005')
    end

    # CA3, and chapter 4.9 §4: « specify secure HTTP ("https://") as transport.
    # The use of "http://" URIs is not allowed. »
    describe 'a preview space' do
      it 'offers a secure address as a link, and says the demonstration stops there' do
        confirm_the_request
        stub_exchange_state(statut: 'preview_required', adressePrevisualisation: 'https://ap.example/preview/1')

        get admin_demo_suivi_path

        expect(response.parsed_body.css("main a[href='https://ap.example/preview/1']")).to be_present
        expect(response.parsed_body.css('main').text).to include("s'arrête ici")
      end

      it 'shows an address the chapter forbids as text, and never as a link' do
        confirm_the_request
        stub_exchange_state(statut: 'preview_required', adressePrevisualisation: 'http://ap.example/preview/1')

        get admin_demo_suivi_path

        expect(response.parsed_body.css("main a[href='http://ap.example/preview/1']")).to be_empty
        expect(response.parsed_body.css('main').text).to include('http://ap.example/preview/1')
      end
    end

    it 'says so when the contract refuses to say anything of the exchange' do
      confirm_the_request
      stub_exchange_state(status: 404, erreur: 'Échange inconnu')

      get admin_demo_suivi_path

      # Les deux identifiants restent : c'est tout ce que le registre tient
      # quand le contrat ne dit rien, et ce par quoi l'exploitant retrouve
      # l'échange au journal.
      expect(response.parsed_body.css('main').text)
        .to include("n'a pas pu être lu", 'Échange inconnu',
          DemoContractStubs::ACCEPTED_EXCHANGE, DemoContractStubs::ACCEPTED_CONVERSATION)
    end

    it 'says so when the contract cannot be reached at all' do
      confirm_the_request
      stub_request(:get, "#{Settings.oots_france_url}/requete/#{DemoContractStubs::ACCEPTED_EXCHANGE}").to_timeout

      get admin_demo_suivi_path

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body.css('main').text)
        .to include("n'a pas pu être joint",
          DemoContractStubs::ACCEPTED_EXCHANGE, DemoContractStubs::ACCEPTED_CONVERSATION)
    end

    it 'sends an operator holding no identity back to the start' do
      confirm_the_request
      reset_session_identity

      get admin_demo_suivi_path

      expect(response).to redirect_to(admin_demo_root_path)
    end

    it 'sends an operator following no exchange back to the form' do
      get admin_demo_suivi_path

      expect(response).to redirect_to(admin_demo_demande_path)
    end
  end
end
