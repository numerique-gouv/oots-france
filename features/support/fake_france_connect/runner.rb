require 'net/http'
require 'uri'
require_relative 'server'

module FakeFranceConnect
  # The scenario's handle on the fake: it starts it, waits for its discovery
  # document to answer, stops it, and drives it over the command surface.
  #
  # A process of its own, and not a thread of the scenario: the local stack
  # will run the fake as a service (OOTS-192), and what the scenario drives — a
  # key rotation, an authorization code aged past its thirty seconds — has to
  # be driven from outside the process, or the scenario could not be played
  # against that one.
  class Runner
    SCRIPT = File.expand_path('server.rb', __dir__)
    STARTUP_TIMEOUT = 30
    POLLING_INTERVAL = 0.2

    def self.discovery_url(issuer) = "#{issuer}/.well-known/openid-configuration"

    # Whether something already serves this address — the local stack, once it
    # runs the fake itself. The scenario then drives that one rather than
    # starting a second on a port already taken.
    def self.answering?(issuer)
      Net::HTTP.get_response(URI.parse(discovery_url(issuer))).is_a?(Net::HTTPSuccess)
    rescue SystemCallError, Timeout::Error, IOError
      false
    end

    def initialize(issuer:, procedure_url:)
      @issuer = issuer
      @procedure_url = procedure_url
    end

    # The child is stopped if it never answers: without this, a failed start
    # leaves a WEBrick holding the port, and the next run fails on something
    # that looks nothing like the first failure.
    def start
      @pid = Process.spawn(child_environment, 'bundle', 'exec', 'ruby', SCRIPT)
      wait_until_answering
      self
    rescue StandardError
      stop
      raise
    end

    def stop
      return if @pid.nil?

      Process.kill('TERM', @pid)
      Process.wait(@pid)
    rescue Errno::ESRCH, Errno::ECHILD => e
      # WEBrick logs to `File::NULL`: without this line, a child that died in
      # the middle of the run would look exactly like one stopped on purpose.
      warn("Le faux FranceConnect+ n'était plus là à l'arrêt — #{e.class}.")
      nil
    end

    def rotate_signing_key = command('rotate-signing-key')

    def age_authorization_codes(seconds) = command('age-authorization-codes', 'seconds' => seconds.to_s)

    def age_access_tokens(seconds) = command('age-access-tokens', 'seconds' => seconds.to_s)

    private

    attr_reader :issuer, :procedure_url

    def child_environment
      ENV.to_h.merge('URL_FAUX_FRANCE_CONNECT' => issuer, 'URL_OOTS_FRANCE' => procedure_url)
    end

    def root
      address = URI.parse(issuer)

      "#{address.scheme}://#{address.host}:#{address.port}"
    end

    def command(name, parameters = {})
      response = Net::HTTP.post_form(URI.parse("#{root}#{Server::COMMANDS}/#{name}"), parameters)
      raise "La commande #{name} du faux FranceConnect+ a répondu #{response.code} : #{response.body}" unless
        response.is_a?(Net::HTTPSuccess)

      response
    end

    # The child has a bundle to load and a WEBrick to bind: without waiting for
    # its discovery document, the first scenario meets a connection refused and
    # the failure looks like a flake when it is a race.
    def wait_until_answering
      limit = monotonic + STARTUP_TIMEOUT

      until self.class.answering?(issuer)
        raise "Le faux FranceConnect+ s'est arrêté au démarrage : ses erreurs sont sur la sortie d'erreur." if dead?
        raise "Le faux FranceConnect+ n'a pas répondu sur #{issuer} en #{STARTUP_TIMEOUT} s." if monotonic > limit

        sleep(POLLING_INTERVAL)
      end
    end

    # A child that died at boot — a port already taken, a bundle that will not
    # load — would otherwise cost the whole timeout and be reported as slow.
    def dead?
      !Process.wait(@pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      true
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
