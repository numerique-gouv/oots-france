# One line of the access points page: a party of the PMode the gateway has
# loaded and the last connectivity test France ran towards it — or a test kept
# for a party that PMode no longer declares, which is information too.
class AccessPointRow
  NEVER_TESTED = 'never_tested'.freeze

  attr_reader :test

  delegate :name, :identifier, :endpoint, to: :@party

  # The parties in the order the gateway lists them, then the tests of the
  # parties it no longer lists, by name. `countries` maps the codes of the
  # country list to their names.
  def self.all(parties:, tests:, countries:)
    tests_by_name = tests.index_by(&:party_name)
    declared = parties.map { |party| new(party:, test: tests_by_name.delete(party.name), countries:, declared: true) }

    declared + tests_by_name.values.sort_by(&:party_name).map { |test| from_test(test, countries) }
  end

  def self.from_test(test, countries)
    party = PmodeParty.new(name: test.party_name, identifier: test.party_identifier,
      identifier_type: test.party_identifier_type, endpoint: nil)

    new(party:, test:, countries:, declared: false)
  end

  private_class_method :from_test

  def initialize(party:, test:, countries:, declared:)
    @party = party
    @test = test
    @countries = countries
    @declared = declared
  end

  def declared? = @declared

  def country_code = @party.country_code(@countries.keys)

  def country_name = @countries[country_code]

  def outcome = test&.outcome || NEVER_TESTED

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
end
