# The ProConnect this deployment declares for its administration space: the
# issuer its discovery document is read from, and the credentials it knows the
# console by. `Settings.proconnect_instance` builds it from the three variables
# of `Settings::PROCONNECT`, or answers `nil` when none is declared.
ProConnectInstance = Data.define(:issuer, :client_id, :client_secret) do
  # The invariants of `FranceConnectInstance`, for its reasons: the issuer
  # without its trailing slash, because `OpenidDiscovery#under_issuer` compares
  # every address it calls to it as a prefix; nothing blank, because an empty
  # credential is refused at `/token`, far from the deployment that could
  # correct it.
  def initialize(issuer:, client_id:, client_secret:)
    { issuer:, client_id:, client_secret: }.each { |name, value| refuse_missing(name, value) }

    super(issuer: issuer.delete_suffix('/'), client_id:, client_secret:)
  end

  private

  def refuse_missing(name, value)
    raise ArgumentError, "ProConnectInstance sans #{name}" if value.to_s.strip.empty?
  end
end
