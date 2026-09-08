# Answers the code lists published with the TDD (chapter 3.5.1) without leaving
# the machine.
#
# Apart from `DirectoryStubs` because the Cucumber World includes this one:
# it rests on `stub_request` alone, where that module also carries doubles built
# on `allow`, which only rspec-mocks provides.
module CodeListStubs
  # The French title `Procedures-CodeList.gc` gives `T1`, verbatim — the page
  # reads it from the list, and no page of the repository writes it down.
  STUDY_FINANCING_LABEL =
    'Demander à un organisme public ou une institution publique le financement d’études supérieures, ' \
    'par exemple par des bourses et des prêts'.freeze

  # The code lists the names come from, served as the Commission's Git
  # repository serves them. Small on purpose: what matters is the column read,
  # not the number of rows. The two lists do not name their French column
  # alike, which is exactly what a double must not smooth over.
  DEFAULT_PROCEDURES = { 'R1' => 'Demander une attestation d’enregistrement d’une naissance' }.freeze
  DEFAULT_COUNTRIES = { 'FR' => 'France (la)', 'FI' => 'Finlande (la)', 'DE' => 'Allemagne (l’)' }.freeze

  def stub_code_list(procedures: DEFAULT_PROCEDURES, countries: DEFAULT_COUNTRIES)
    stub_code_list_at(CodeListClient::PROCEDURES, procedures, 'name-FR')
    stub_code_list_at(CodeListClient::COUNTRIES, countries, 'french')
  end

  def stub_code_list_at(url, names, column)
    rows = names.map do |code, name|
      "<Row><Value ColumnRef='code'><SimpleValue>#{code}</SimpleValue></Value>" \
        "<Value ColumnRef='#{column}'><SimpleValue>#{name}</SimpleValue></Value></Row>"
    end

    stub_request(:get, url).to_return(
      body: "<?xml version='1.0'?><gc:CodeList xmlns:gc='http://docs.oasis-open.org/codelist/ns/genericode/1.0/'>" \
            "<SimpleCodeList>#{rows.join}</SimpleCodeList></gc:CodeList>",
    )
  end
end
