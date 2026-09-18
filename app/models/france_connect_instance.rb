# One FranceConnect+ this deployment declares: the issuer its discovery document
# is read from, and the credentials it knows this client by.
#
# A deployment declares the fake FranceConnect+ this repository runs, the real
# one, or both — `Settings::FRANCE_CONNECT` names the variables of each — and
# the home page of the demonstration offers one card per declaration. The name
# is what the card's submission carries and what the session keeps, so that
# everything the identification does afterwards addresses the FranceConnect+ the
# operator departed on: the code exchange, the UserInfo, the issuer the ID Token
# is checked against, and the sign-out.
#
# Values and nothing else: `Settings` builds them from the variables a
# deployment declares, nothing reads one back from a session, and no two of them
# differ by a line of code.
FranceConnectInstance = Data.define(:name, :issuer, :client_id, :client_secret) do
  # The three invariants everything else rests on, held by the type rather than
  # by the one caller that happens to build it today.
  #
  # The issuer arrives **without its trailing slash**, because
  # `FranceConnectClient#under_issuer` refuses a published endpoint by comparing
  # the address it will call to this string as a prefix. A slash left on would
  # break that comparison on the portal's own addresses, and that comparison is
  # what keeps the `client_secret` and the access token from travelling to
  # whoever wrote the discovery document.
  #
  # None of the three may be blank: an empty issuer is an address of nothing,
  # and an empty credential is refused at `/token` — far from the deployment
  # that could correct it.
  def initialize(issuer:, client_id:, client_secret:, **)
    { issuer:, client_id:, client_secret: }.each { |name, value| refuse_missing(name, value) }

    super(issuer: issuer.delete_suffix('/'), client_id:, client_secret:, **)
  end

  private

  def refuse_missing(name, value)
    raise ArgumentError, "FranceConnectInstance sans #{name}" if value.to_s.strip.empty?
  end
end
