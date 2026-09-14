# Answers the code lists published with the TDD (chapter 3.5.1) without leaving
# the machine.
#
# Apart from `DirectoryStubs` because the Cucumber World includes this one:
# it rests on `stub_request` alone, where that module also carries doubles built
# on `allow`, which only rspec-mocks provides.
module CodeListStubs
  # The two titles `Procedures-CodeList.gc` gives `T1`, verbatim — the pages
  # read them from the list, and no page of the repository writes one down.
  STUDY_FINANCING_LABEL =
    'Demander à un organisme public ou une institution publique le financement d’études supérieures, ' \
    'par exemple par des bourses et des prêts'.freeze
  STUDY_FINANCING_NAME =
    'Applying for a tertiary education study financing, such as study grants and loans from a public ' \
    'body or institution'.freeze

  # The code lists the names come from, served as the Commission's Git
  # repository serves them. Small on purpose: what matters is the column read,
  # not the number of rows. No two of these columns carry the same value, which
  # is exactly what a double must not smooth over — the two lists do not name
  # their French column alike, and the procedures publish their English names in
  # a column named after no language at all.
  DEFAULT_PROCEDURES = { 'R1' => 'Demander une attestation d’enregistrement d’une naissance' }.freeze
  DEFAULT_PROCEDURE_NAMES = { 'R1' => 'Requesting a birth registration certificate' }.freeze
  DEFAULT_COUNTRIES = { 'FR' => 'France (la)', 'FI' => 'Finlande (la)', 'DE' => 'Allemagne (l’)' }.freeze
  DEFAULT_COUNTRY_NAMES = { 'FR' => 'France', 'FI' => 'Finland', 'DE' => 'Germany' }.freeze

  def stub_code_list(procedures: DEFAULT_PROCEDURES, procedure_names: DEFAULT_PROCEDURE_NAMES,
                     countries: DEFAULT_COUNTRIES, country_names: DEFAULT_COUNTRY_NAMES)
    stub_code_list_at(CodeListClient::PROCEDURES, 'name-FR' => procedures, 'name-Value' => procedure_names)
    stub_code_list_at(CodeListClient::COUNTRIES, 'french' => countries, 'name' => country_names)
  end

  # One row per code any of the columns names, carrying only the columns that
  # name it: a code list publishes a translation it has and no cell where it has
  # none.
  def stub_code_list_at(url, names_by_column)
    rows = names_by_column.values.flat_map(&:keys).uniq.map do |code|
      values = names_by_column.filter_map do |column, names|
        "<Value ColumnRef='#{column}'><SimpleValue>#{names[code]}</SimpleValue></Value>" if names[code]
      end

      "<Row><Value ColumnRef='code'><SimpleValue>#{code}</SimpleValue></Value>#{values.join}</Row>"
    end

    stub_request(:get, url).to_return(
      body: "<?xml version='1.0'?><gc:CodeList xmlns:gc='http://docs.oasis-open.org/codelist/ns/genericode/1.0/'>" \
            "<SimpleCodeList>#{rows.join}</SimpleCodeList></gc:CodeList>",
    )
  end
end
