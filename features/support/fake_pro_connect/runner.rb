require 'net/http'
require 'uri'

module FakeProConnect
  # Starts the fake as a child process when nothing answers at its issuer, and
  # stops it — the same handle `FakeFranceConnect::Runner` is, without the
  # commands: no scenario drives this one from the outside.
  class Runner
    SCRIPT = File.expand_path('server.rb', __dir__)
    STARTUP_TIMEOUT = 30
    POLLING_INTERVAL = 0.2

    def self.answering?(issuer)
      Net::HTTP.get_response(URI.parse("#{issuer}/.well-known/openid-configuration")).is_a?(Net::HTTPSuccess)
    rescue SystemCallError, Timeout::Error, IOError
      false
    end

    def initialize(issuer:, application_url:)
      @issuer = issuer
      @application_url = application_url
    end

    def start
      @pid = Process.spawn(ENV.to_h.merge('URL_PROCONNECT' => issuer, 'URL_OOTS_FRANCE' => application_url,
        'PORT_FAUX_PROCONNECT' => URI.parse(issuer).port.to_s), 'bundle', 'exec', 'ruby', SCRIPT)
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
      warn("Le faux ProConnect n'était plus là à l'arrêt — #{e.class}.")
      nil
    end

    private

    attr_reader :issuer, :application_url

    def wait_until_answering
      limit = monotonic + STARTUP_TIMEOUT

      until self.class.answering?(issuer)
        raise "Le faux ProConnect s'est arrêté au démarrage : ses erreurs sont sur la sortie d'erreur." if dead?
        raise "Le faux ProConnect n'a pas répondu sur #{issuer} en #{STARTUP_TIMEOUT} s." if monotonic > limit

        sleep(POLLING_INTERVAL)
      end
    end

    def dead?
      !Process.wait(@pid, Process::WNOHANG).nil?
    rescue Errno::ECHILD
      true
    end

    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
