require 'rails_helper'

# What the profile declares is asserted on real `OpenSSL::SSL::SSLContext`
# objects, and what it refuses is asserted by handshaking against a throwaway
# server on the loopback. Each refusal comes with its counter-proof — the same
# handshake by a context the profile has not touched, which succeeds —, and is
# matched on the alert OpenSSL actually sends rather than on the error class
# alone. Without both, an example would pass just as well on a build whose
# OpenSSL refused the thing on its own, or on one where the profile is simply
# broken and every context raises: the two failure modes this file exists to
# tell apart.
RSpec.describe TlsProfile do
  let(:server_key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:server_certificate) do
    OpenSSL::X509::Certificate.new.tap do |certificate|
      certificate.version = 2
      certificate.serial = 1
      certificate.subject = OpenSSL::X509::Name.parse('/CN=localhost')
      certificate.issuer = certificate.subject
      certificate.public_key = server_key
      certificate.not_before = 1.minute.ago.utc
      certificate.not_after = 1.hour.from_now.utc
      certificate.sign(server_key, OpenSSL::Digest.new('SHA256'))
    end
  end

  # The profile is applied to every context the process opens, so a value this
  # OpenSSL will not take is not a failed example but an application that
  # cannot open a connection at all.
  describe 'the profile itself' do
    it 'is one this OpenSSL accepts' do
      expect { profiled_context }.not_to raise_error
    end

    # Three lists that each satisfy the chapter can still leave nothing in
    # common between them, and no other example here would notice: they are all
    # either a refusal, or a handshake by a context the profile has not touched.
    it 'still completes an ordinary handshake' do
      expect(handshake(client: profiled_context, server: server_context)).to start_with('TLSv1')
    end

    # The escape hatch stated at the top of the initializer, and the whole of
    # what makes it reversible connection by connection: reversing the merge
    # would take it away without any other example changing colour.
    it 'gives way to a caller that sets its own floor' do
      client = OpenSSL::SSL::SSLContext.new
      client.security_level = 0
      client.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE,
        min_version: OpenSSL::SSL::TLS1_1_VERSION,
        ciphers: 'DEFAULT@SECLEVEL=0')

      expect(handshake(client:, server: server_bound_to_tls_1_1)).to eq('TLSv1.1')
    end
  end

  describe 'the cipher suites offered' do
    subject(:offered) { cipher_names(profiled_context) }

    it 'adds the three CCM suites chapter 3.3 names' do
      expect(offered).to include('TLS_AES_128_CCM_SHA256', 'ECDHE-ECDSA-AES256-CCM', 'ECDHE-ECDSA-AES128-CCM')
    end

    # The guard against reading the two lists of §3.3 as a restriction: it
    # permits further suites expressly, and forbids none.
    it 'withdraws none of those OpenSSL offered on its own' do
      expect(offered).to include(*cipher_names(bare_context))
    end
  end

  describe 'the groups offered' do
    subject(:groups) { described_class::GROUPS.split(':') }

    it 'declares the five curves of chapter 3.4 and ffdhe3072' do
      expect(groups).to include('secp256r1', 'secp384r1', 'secp521r1', 'x25519', 'x448', 'ffdhe3072')
    end

    it 'no longer declares ffdhe2048' do
      expect(groups).not_to include('ffdhe2048')
    end

    # A list filtered down to nothing would be accepted by `groups=` and only
    # fail at the first handshake, so the emptiness is asserted here rather
    # than waited for there.
    it 'is never empty, whatever the build accepts' do
      expect(groups).not_to be_empty
    end

    # Exercised directly, because what the filter does depends on which names
    # the build happens to know — and on a build that knows them all, no other
    # example here tells "the filter works" from "there was nothing to filter".
    it 'keeps the names this OpenSSL accepts and drops the rest' do
      expect(described_class.send(:settable_groups, %w[x25519 not-a-real-group])).to eq(%w[x25519])
    end

    # `SSLContext` exposes no reader for the groups, so the withdrawal is
    # observed where it has its effect: against a server that offers nothing
    # else, the profiled client has no group left to agree on.
    it 'refuses a server offering nothing but ffdhe2048' do
      client = profiled_context

      expect { handshake(client:, server: server_offering_only('ffdhe2048')) }
        .to raise_error(OpenSSL::SSL::SSLError, /handshake failure|shared/i)
    end

    it 'is what refuses it, an untouched context reaching that server' do
      expect(handshake(client: bare_context, server: server_offering_only('ffdhe2048'))).to eq('TLSv1.3')
    end

    # The other half of the same seam: the groups it does declare are not just
    # a string, they are what gets offered. Against a server that accepts
    # nothing else, only a client that really offers `ffdhe3072` gets through.
    it 'agrees with a server offering nothing but ffdhe3072' do
      expect(handshake(client: profiled_context, server: server_offering_only('ffdhe3072'))).to eq('TLSv1.3')
    end
  end

  describe 'the version floor' do
    it 'refuses a server bound to TLS 1.1' do
      client = profiled_context

      expect { handshake(client:, server: server_bound_to_tls_1_1) }
        .to raise_error(OpenSSL::SSL::SSLError, /protocol version/i)
    end

    # The floor has to come from here rather than from the base image, which is
    # what this pair establishes: a context left as an OpenSSL still tolerating
    # TLS 1.1 would leave it negotiating TLS 1.1, and the same context refuses
    # it once `set_params` has run. Nothing but the profile separates the two.
    it 'is what refuses it, on a context whose own settings would accept it' do
      expect(handshake(client: lax_context, server: server_bound_to_tls_1_1)).to eq('TLSv1.1')

      client = profiled(lax_context)

      expect { handshake(client:, server: server_bound_to_tls_1_1) }
        .to raise_error(OpenSSL::SSL::SSLError, /protocol version/i)
    end
  end

  def cipher_names(context) = context.ciphers.map(&:first)

  # Never through `set_params`, so the profile is not applied to it.
  def bare_context
    OpenSSL::SSL::SSLContext.new.tap { |context| context.verify_mode = OpenSSL::SSL::VERIFY_NONE }
  end

  def profiled_context = profiled(OpenSSL::SSL::SSLContext.new)

  def profiled(context)
    context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE)
    context
  end

  # Configured the way an OpenSSL that still tolerated TLS 1.1 would leave a
  # context: the security level and the version floor are set on the context
  # itself, where a base image's defaults sit, and not passed as parameters —
  # those the profile deliberately lets the caller win.
  def lax_context
    bare_context.tap do |context|
      context.security_level = 0
      context.min_version = OpenSSL::SSL::TLS1_1_VERSION
      context.ciphers = 'DEFAULT@SECLEVEL=0'
    end
  end

  def server_context
    OpenSSL::SSL::SSLContext.new.tap do |context|
      context.cert = server_certificate
      context.key = server_key
    end
  end

  def server_offering_only(group) = server_context.tap { |context| context.groups = group }

  # A security level of nought, and `@SECLEVEL=0` on the list, are what it takes
  # to get OpenSSL 3.5 to serve a protocol it considers broken.
  def server_bound_to_tls_1_1
    server_context.tap do |context|
      context.security_level = 0
      context.min_version = OpenSSL::SSL::TLS1_1_VERSION
      context.max_version = OpenSSL::SSL::TLS1_1_VERSION
      context.ciphers = 'DEFAULT@SECLEVEL=0'
    end
  end

  # Returns the version negotiated, and lets the client's error through: it is
  # what half of these examples assert. The port is the one the OS hands out,
  # so parallel runs cannot collide.
  def handshake(client:, server:)
    listener = OpenSSL::SSL::SSLServer.new(TCPServer.new('127.0.0.1', 0), server)
    # The client walking away is what several examples are about; a broken
    # harness is not, and keeps propagating out of the thread.
    accepting = Thread.new do
      listener.accept.close
    rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET, Errno::EPIPE, IOError
      nil
    end
    socket = OpenSSL::SSL::SSLSocket.new(TCPSocket.new('127.0.0.1', listener.to_io.local_address.ip_port), client)

    begin
      socket.connect
      socket.ssl_version
    ensure
      socket.close
      accepting.join(5)
      listener.close
    end
  end
end
