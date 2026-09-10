# The environment `Settings::Contract` is content with, built here rather than
# in one spec because two of them ask something to start on it: the contract
# itself, and the initializer that makes the worker read it.
module SettingsEnvironment
  # Those read as numbers need one, the others take anything non-blank. The two
  # timeouts are added rather than indexed — they leave REQUIRED to a deployment
  # that provides the dispositif — and take the values of the table of chapter
  # 4.4.3: the contract refuses them equal, which one value for every number
  # would make them.
  def complete_environment
    Settings::REQUIRED
      .index_with { |name| name.in?(Settings::NUMERIC) ? '1000' : 'valeur' }
      .merge('DELAI_EXPIRATION_REQUETEUR_MINUTES' => '6', 'DELAI_EXPIRATION_FOURNISSEUR_MINUTES' => '5')
      .merge('CLE_PRIVEE_JWK_DEMARCHE_EN_BASE64' => france_connect_key)
      .merge('CLE_PRIVEE_JWK_SIGNATURE_DEMARCHE_EN_BASE64' => demo_signing_key)
  end

  # The contract reads this one rather than merely finding it filled: it must
  # decode to a JWK, and declare an algorithm FranceConnect+ accepts.
  def france_connect_key(algorithm = 'RSA-OAEP-256')
    Base64.strict_encode64({ kty: 'RSA', alg: algorithm, use: 'enc' }.to_json)
  end

  # Read as well, and on another axis: it is the type and the curve that decide
  # here, ES256 being defined on P-256 alone.
  def demo_signing_key(kty: 'EC', crv: 'P-256')
    Base64.strict_encode64({ kty:, crv:, use: 'sig' }.compact.to_json)
  end

  def with_environment(variables)
    anciennes = variables.keys.index_with { |name| ENV.fetch(name, nil) }
    variables.each { |name, value| ENV[name] = value }
    yield
  ensure
    anciennes.each { |name, value| ENV[name] = value }
  end
end

RSpec.configure { |config| config.include(SettingsEnvironment) }
