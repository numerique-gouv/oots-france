require 'rails_helper'

RSpec.describe 'POST /domibus/notifications' do
  let(:credentials) { { login: 'domibus_push', password: 'secret' } }
  let(:headers) do
    {
      'CONTENT_TYPE' => 'text/xml',
      'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic
        .encode_credentials(credentials[:login], credentials[:password]),
    }
  end

  let(:receive_success) do
    <<~XML
      <soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
        <soap:Body>
          <ns:receiveSuccess xmlns:ns="http://eu.domibus.wsplugin/">
            <messageID>45fa5345-5a18-4691-945f-531f9568729f@oots.eu</messageID>
          </ns:receiveSuccess>
        </soap:Body>
      </soap:Envelope>
    XML
  end

  before { allow(Settings).to receive(:gateway_notification_credentials).and_return(credentials) }

  it 'acknowledges at once and queues the work' do
    expect { post '/domibus/notifications', params: receive_success, headers: }
      .to have_enqueued_job(ProcessIncomingMessageJob).with('45fa5345-5a18-4691-945f-531f9568729f@oots.eu')

    expect(response).to have_http_status(:ok)
  end

  # The gateway is entitled to a prompt answer: holding its connection while a
  # message is fetched, an answer built and submitted would turn a slow
  # correspondent into a lost notification.
  it 'does not do the work in the request itself' do
    expect(IncomingMessage::Process).not_to receive(:call)

    post '/domibus/notifications', params: receive_success, headers: headers
  end

  # The other operations report on messages *we* sent. Acknowledged so the
  # gateway stops retrying, and nothing more for now.
  it 'acknowledges an operation it has nothing to do about' do
    envelope = receive_success.sub('receiveSuccess', 'sendSuccess').sub('/ns:receiveSuccess', '/ns:sendSuccess')

    expect { post '/domibus/notifications', params: envelope, headers: headers }
      .not_to have_enqueued_job(ProcessIncomingMessageJob)

    expect(response).to have_http_status(:ok)
  end

  describe 'a request of ours that did not reach its recipient' do
    let(:status_change) { built_envelope('domibus/changementStatut') }

    it 'queues the reading of an attempt the gateway will retry' do
      expect { post '/domibus/notifications', params: status_change, headers: }
        .to have_enqueued_job(RecordDeliveryFailureJob)
        .with('8a1c0e3f-7b2d-4c6e-9f10-2d3e4f5a6b7c@oots.eu', 'WAITING_FOR_RETRY')

      expect(response).to have_http_status(:ok)
    end

    it 'queues the verdict of a gateway that gave up' do
      envelope = status_change.sub('WAITING_FOR_RETRY', 'SEND_FAILURE')

      expect { post '/domibus/notifications', params: envelope, headers: }
        .to have_enqueued_job(RecordDeliveryFailureJob)
        .with('8a1c0e3f-7b2d-4c6e-9f10-2d3e4f5a6b7c@oots.eu', 'SEND_FAILURE')
    end

    # The rule pushes every change of every message, either way round.
    it 'acknowledges any other status without doing anything' do
      %w[ACKNOWLEDGED SEND_ENQUEUED].each do |status|
        envelope = status_change.sub('WAITING_FOR_RETRY', status)

        expect { post '/domibus/notifications', params: envelope, headers: }
          .not_to have_enqueued_job

        expect(response).to have_http_status(:ok)
      end
    end

    # `sendFailure` depends on the PMode, and the rule does not push it.
    it 'acknowledges the operations the rule does not push without doing anything' do
      %w[sendFailure receiveFailure].each do |operation|
        envelope = receive_success.gsub('receiveSuccess', operation)

        expect { post '/domibus/notifications', params: envelope, headers: }
          .not_to have_enqueued_job

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'authentication' do
    # This route triggers processing and is reachable from the network:
    # unauthenticated, anyone could provoke a retrieval from the gateway.
    it 'refuses an unauthenticated call' do
      post '/domibus/notifications', params: receive_success, headers: { 'CONTENT_TYPE' => 'text/xml' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses the wrong password' do
      wrong = ActionController::HttpAuthentication::Basic.encode_credentials('domibus_push', 'autre')

      post '/domibus/notifications', params: receive_success,
        headers: headers.merge('HTTP_AUTHORIZATION' => wrong)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # 400 rather than 500: the gateway retries a 500 with the same body, and a
  # body we cannot read will not become readable.
  it 'refuses a body it cannot read, without inviting a retry' do
    post '/domibus/notifications', params: 'pas du xml <', headers: headers

    expect(response).to have_http_status(:bad_request)
  end
end
