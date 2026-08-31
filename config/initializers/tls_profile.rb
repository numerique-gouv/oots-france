# The TLS profile chapter 3.7 of the TDD asks an Evidence Requester to offer:
# TLS 1.2 as a floor (§3.2), the CCM suites of §3.3, and groups no weaker than
# `ffdhe3072` (§3.4). Posting it here is what turns the two "it MUST be
# possible to configure…" of §3.1 into something this repository actually
# exercises, rather than something OpenSSL happens to default to.
# <https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932927>
#
# An initializer, and not a class under `app/`: the last line has to run once
# at boot, before anything opens a connection, and a constant defined under
# `app/` is not reachable from here — Zeitwerk resolves those lazily, so naming
# one during initialization raises `uninitialized constant`.
#
# Prefixing `set_params` rather than passing Faraday an `ssl:` option, because
# no option can carry this. `Faraday::SSLOptions` and `Net::HTTP::SSL_ATTRIBUTES`
# both know `ciphers` and `min_version`, and neither knows `ciphersuites` nor
# the group list; and `Net::HTTP#connect` builds its own `SSLContext` and hands
# `set_params` a hash it assembles in a local variable, so there is no context
# to inject either. `set_params` is the one call it always makes.
#
# The caller's own parameters win over the profile, which is what makes this
# reversible connection by connection.
module TlsProfile
  # Groups only, because the three setters do not fail alike: `ciphers=` and
  # `ciphersuites=` drop a name they cannot resolve and keep the rest, so an
  # unknown one there costs a suite, whereas `SSL_CTX_set1_groups_list` rejects
  # the **whole** list over a single unknown name. Since the profile is applied
  # to every context the process opens, that would turn one unknown group into
  # a raise on every outgoing connection.
  #
  # Not a hypothetical: `X25519MLKEM768` reached OpenSSL only in 3.5, and the
  # library this process links against is not the Ruby version pinned in six
  # places — the `ruby:4.0.6-slim` image and a bare CI runner disagree on it.
  def self.settable_groups(names)
    names.select do |name|
      OpenSSL::SSL::SSLContext.new.groups = name
      true
    rescue OpenSSL::SSL::SSLError
      false
    end
  end
  private_class_method :settable_groups

  # §3.3 names three CCM suites among those an implementation "should support",
  # and OpenSSL puts none of them in its default list. A cipher string cannot
  # add them back: the CCM suites live in `COMPLEMENTOFDEFAULT`, which the
  # `DEFAULT` keyword removes with a `!`, and OpenSSL never reinstates a suite
  # a `!` has removed — `ciphers = 'DEFAULT:ECDHE-ECDSA-AES256-CCM'` offers no
  # CCM at all. So the list is derived from the default one and appended to,
  # which also makes "nothing was withdrawn" something a spec can assert.
  # Appended, not prepended: the chapter lists the GCM suites first.
  #
  # TLS 1.3 suites are named in `ciphers` too but configured through their own
  # setter, so they are dropped from this list rather than set twice.
  CIPHERS = (OpenSSL::SSL::SSLContext.new.ciphers
                                     .reject { |_name, version, _bits, _algorithm_bits| version == 'TLSv1.3' }
                                     .map(&:first) + %w[ECDHE-ECDSA-AES256-CCM ECDHE-ECDSA-AES128-CCM]).join(':').freeze

  # TLS 1.3 has no "the default, plus…" form, so the three OpenSSL already
  # offers are written out alongside the `TLS_AES_128_CCM_SHA256` of §3.3. A
  # strict superset of the default: this adds, it does not restrict.
  CIPHERSUITES = %w[
    TLS_AES_256_GCM_SHA384
    TLS_CHACHA20_POLY1305_SHA256
    TLS_AES_128_GCM_SHA256
    TLS_AES_128_CCM_SHA256
  ].join(':').freeze

  # The five curves of §3.4 and `ffdhe3072`, in the order OpenSSL offered them,
  # minus `ffdhe2048`: a server following the client's preference would
  # otherwise land on 2048 bits, below the floor the chapter recommends.
  #
  # `X25519MLKEM768` is offered ahead of them wherever the build knows it,
  # although §3.4 does not name it. The chapter introduces its list with
  # "should support the following", which obliges us to offer those and never
  # forbids offering more; dropping the hybrid post-quantum exchange to match a
  # list written before it existed would be a weakening carried out in
  # conformance's name.
  GROUPS = settable_groups(%w[
    X25519MLKEM768
    x25519
    secp256r1
    x448
    secp384r1
    secp521r1
    ffdhe3072
  ]).join(':').freeze

  PROFILE = {
    min_version: OpenSSL::SSL::TLS1_2_VERSION,
    ciphers: CIPHERS,
    ciphersuites: CIPHERSUITES,
    groups: GROUPS
  }.freeze

  def set_params(params = {}) = super(PROFILE.merge(params))
end

# Every TLS context this process opens, which is wider than the four Common
# Services connections §3.7 governs: `DomibusClient` reaches the gateway over
# `URL_BASE_DOMIBUS`, which is an `https://` URL in a real deployment, so the
# profile applies there too. That is accepted rather than worked around,
# because per-connection is not a granularity `Net::HTTP` offers, and because
# what the profile does to that connection is a hardening: three suites added
# and none withdrawn, the version floor raised, and a single group dropped for
# being below the recommended floor while the five curves of §3.4 stay on
# offer. The eDelivery profile of chapter 4.7, which does govern that hop,
# asks for TLS 1.2 at a minimum too.
# <https://ec.europa.eu/digital-building-blocks/sites/spaces/TDD/pages/973932931>
OpenSSL::SSL::SSLContext.prepend(TlsProfile)
