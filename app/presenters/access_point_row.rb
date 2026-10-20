# One line of the access points page: a party of the PMode the gateway has
# loaded and the last connectivity test France ran towards it — or a test kept
# for a party that PMode no longer declares, which is information too.
class AccessPointRow
  NEVER_TESTED = 'never_tested'.freeze

  attr_reader :test

  delegate :name, :identifier, :endpoint, to: :@party

  # Ordered by `rank`. A test kept for a party the PMode no longer lists says
  # nothing of today's connectivity, whatever its outcome, hence last.
  # `countries` maps the codes of the country list to their names;
  # `certificates` are the entries of the gateway's truststore, stored under
  # the names of the parties — Java keystore aliases, which ignore case.
  def self.all(parties:, tests:, countries:, certificates:)
    tests_by_name = tests.index_by(&:party_name)
    certificates_by_alias = certificates.index_by { |entry| entry.name.to_s.downcase }
    declared = parties.map do |party|
      new(party:, test: tests_by_name.delete(party.name), countries:, certificates_by_alias:, declared: true)
    end
    undeclared = tests_by_name.values.map { |test| from_test(test, countries, certificates_by_alias) }

    (declared + undeclared).sort_by(&:rank)
  end

  def self.from_test(test, countries, certificates_by_alias)
    party = PmodeParty.new(name: test.party_name, identifier: test.party_identifier,
      identifier_type: test.party_identifier_type, endpoint: nil)

    new(party:, test:, countries:, certificates_by_alias:, declared: false)
  end

  private_class_method :from_test

  def initialize(party:, test:, countries:, certificates_by_alias:, declared:)
    @party = party
    @test = test
    @countries = countries
    @certificates_by_alias = certificates_by_alias
    @declared = declared
  end

  def declared? = @declared

  def country_code = @party.country_code(@countries.keys, certificate: @certificates_by_alias[name.to_s.downcase])

  def country_name = @countries[country_code]

  def outcome = test&.outcome || NEVER_TESTED

  def rank = [group, country_name ? 0 : 1, country_name.to_s, name.to_s]

  # The identifier only where the name does not already say it: a party
  # declared under an `EAS` scheme is named one way and addressed another.
  def distinct_identifier = (identifier unless identifier == name)

  # What the gateway said of a failure — the code of its error and its
  # detail, or the words of a refusal that named no code.
  def error_code = test&.error_code

  def error_text = error_code ? test.error_detail : test&.submission_refusal

  # A party the PMode no longer declares cannot be addressed, and one whose
  # test is pending must not be restarted.
  def testable? = declared? && @party.addressable? && !test&.pending?

  private

  def group
    return 2 unless declared?

    test&.acknowledged? ? 0 : 1
  end
end
