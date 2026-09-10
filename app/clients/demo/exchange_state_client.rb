module Demo
  # The demonstration procedure reading back the state of the exchange it opened,
  # over HTTP and through the published contract — `GET /requete/:exchange_id`,
  # the address `docs/oots_context.md` gives a French service provider.
  #
  # Over HTTP for the reason `EvidenceRequestClient` is: the procedure holds no
  # privilege over the deployment it calls, and reading the `exchanges` table it
  # sits next to would prove nothing an integrator could reproduce. What it knows
  # of its exchange is what the contract says of it.
  #
  # It reads and never writes. Chapter 4.4 §4.1 is why the tracking page may
  # refresh as often as it likes: « to return more references to the Online
  # Procedure Portal, even if it is for the same user in the same session, for
  # the same evidency type and data service, a new unique request MUST be
  # issued » — so consulting is one call, and asking again is another journey.
  class ExchangeStateClient
    PATH = '/requete'.freeze

    def initialize(connection: Faraday.new)
      @connection = connection
    end

    def fetch(exchange_id)
      response = connection.get("#{Settings.oots_france_url}#{PATH}/#{CGI.escape(exchange_id.to_s)}")

      ContractAnswer.from(response, path: PATH)
    rescue Faraday::Error => e
      raise DemoContractError, I18n.t('clients.demo.exchange_state_client.unreachable', error: e.message)
    end

    private

    attr_reader :connection
  end
end
