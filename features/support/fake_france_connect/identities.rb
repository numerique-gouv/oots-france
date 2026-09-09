module FakeFranceConnect
  # One test identity of a member state's eIDAS node, as the bridge hands it to
  # FranceConnect+ once translated.
  #
  # Names of use, invented: « Il est interdit d'utiliser de vraies données
  # personnelles sur l'environnement bac à sable » holds here too, and these
  # identities are the fake's own, like the named users of the mock node the
  # FranceConnect sources ship.
  class Identity
    # The bridge maps an eIDAS level of assurance onto an ACR value, and it is
    # that one the core keeps as long as its own configuration admits it —
    # `getInteractionAcr` falls back on the level the service provider asked
    # for otherwise, a case no configuration of the fake can reach.
    # back/libs/eidas-oidc-mapper/src/mappers/eidas-to-oidc.mapper.ts
    # back/libs/oidc-acr/src/oidc-acr.service.ts
    ACR_BY_LEVEL = { 'low' => 'eidas2', 'substantial' => 'eidas2', 'high' => 'eidas3' }.freeze

    # Which claims each scope covers, and the reason `preferred_username` is not
    # among what `family_name` yields: the core publishes it under `profile` and
    # under a scope of its own, so a procedure asking for a family name gets a
    # family name.
    # back/libs/scopes/src/data/fcp-high/fcp-high.scopes.ts
    CLAIMS_BY_SCOPE = {
      'given_name' => %w[given_name],
      'family_name' => %w[family_name],
      'birthdate' => %w[birthdate],
      'gender' => %w[gender],
      'birthplace' => %w[birthplace],
      'preferred_username' => %w[preferred_username],
      'profile' => %w[given_name family_name birthdate gender preferred_username],
    }.freeze

    attr_reader :key, :country, :level, :eidas_identifier, :given_name, :family_name, :birthdate

    def initialize(key:, country:, level:, eidas_identifier:, given_name:, family_name:, birthdate:,
                   gender: nil, birthplace: nil)
      @key = key
      @country = country
      @level = level
      @eidas_identifier = eidas_identifier
      @given_name = given_name
      @family_name = family_name
      @birthdate = birthdate
      @gender = gender
      @birthplace = birthplace
    end

    def acr = ACR_BY_LEVEL.fetch(level)

    def label = "#{given_name} #{family_name} (#{birthdate})"

    # What `/userinfo` answers, `sub` excepted: the claims the requested scopes
    # cover, minus those this identity has not got. The bridge renders a
    # European user with **no** identifier and **no** country, and the fake
    # reproduces that gap rather than filling it — which is why neither
    # `birthcountry` nor `email` appears in the map above.
    # back/libs/eidas-oidc-mapper/src/mappers/eidas-to-oidc.mapper.ts
    def claims_for(scopes)
      covered = scopes.flat_map { |scope| CLAIMS_BY_SCOPE.fetch(scope, []) }.uniq

      values.slice(*covered)
    end

    private

    attr_reader :gender, :birthplace

    # `preferred_username` is the family name: the bridge has no other name to
    # put there, a European user carrying no birth name.
    def values
      {
        'given_name' => given_name, 'family_name' => family_name, 'birthdate' => birthdate,
        'gender' => gender, 'birthplace' => birthplace, 'preferred_username' => family_name,
      }.compact
    end
  end

  # The identities the fake serves, and the countries its first page offers —
  # which are exactly the countries it has an identity for, so that a button
  # always leads somewhere.
  module Identities
    COUNTRY_NAMES = { 'DK' => 'Denmark' }.freeze

    ALL = [
      Identity.new(
        key: 'dk-substantial', country: 'DK', level: 'substantial',
        eidas_identifier: 'DK/FR/61f6a1b0-3d3c-4f24-9a2f-6d1c9f0f2a55',
        given_name: 'Freja Marie', family_name: 'Sørensen', birthdate: '2001-04-17',
        gender: 'female', birthplace: 'Aarhus',
      ),
      Identity.new(
        key: 'dk-high', country: 'DK', level: 'high',
        eidas_identifier: 'DK/FR/8c0d5ea2-77b1-4f0e-8f5a-2b93c4d61e07',
        given_name: 'Mikkel Anker', family_name: 'Bruun', birthdate: '1998-09-03',
      ),
    ].freeze

    def self.countries = ALL.map(&:country).uniq

    def self.country_name(code) = COUNTRY_NAMES.fetch(code, code)

    def self.of_country(code) = ALL.select { |identity| identity.country == code }

    def self.find(key) = ALL.find { |identity| identity.key == key }
  end
end
