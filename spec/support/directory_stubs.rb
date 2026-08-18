# Answers the central directories with what they really answered, captured on
# the acceptance environment.
#
# Only the DNS is doubled. The signature of each answer is verified for real,
# against the trust store the deployment carries, so a spec built on this
# exercises the whole HTTP boundary — version header, refusal codes, signature
# — and not a shape someone wrote down.
module DirectoryStubs
  ACCEPTANCE = 'https://query.cs.acc.oots.tech.ec.europa.eu'.freeze

  def stub_directory_resolution
    allow(CommonServicesInstance).to receive(:new) do |service|
      instance_double(CommonServicesInstance, base_url: "#{ACCEPTANCE}/#{service}/")
    end
  end

  # The two Evidence Broker queries share an address and are told apart by
  # their `queryId`.
  def stub_directory(service, query_fragment, fixture)
    body, headers = common_services_answer(fixture)

    stub_directory_body(service, query_fragment, body, headers)
  end

  def stub_directory_body(service, query_fragment, body, headers = { 'content-type' => 'application/x-ebrs+xml' })
    stub_request(:get, "#{ACCEPTANCE}/#{service}/rest/search")
      .with(query: hash_including('queryId' => a_string_including(query_fragment)))
      .to_return(body:, headers:)
  end

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

  # A body altered to make a case the captured answers do not hold no longer
  # matches the signature that came with it, and that check is what would fail
  # first. Doubling it is the only way to serve a hand-made answer through the
  # whole client.
  def stub_directory_signature
    allow(CommonServicesSignature).to receive(:new)
      .and_return(instance_double(CommonServicesSignature, verify!: true))
  end
end
