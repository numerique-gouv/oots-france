# The data services holding an evidence type in a country, as the Data Service
# Directory returns them (chapter 3.1.4).
#
# `sdg:AccessService/sdg:Identifier` is the ebCore party identifier of the
# gateway, and its `schemeID` the scheme naming it: OOTS runs no SMP, so
# chapter 4.7 has this identifier matched against a statically configured
# PMode, which is what says at which address the party answers.
class DataServicesResponseParser < CommonServicesResponseParser
  DATA_SERVICE = "./rim:Slot[@name='DataServiceEvidenceType']/rim:SlotValue/sdg:DataServiceEvidenceType".freeze

  CLASSIFICATION_CONCEPTS = 'UserRequestedClassificationConcepts'.freeze

  ADDRESS_LINES = {
    country: 'AdminUnitLevel1', thoroughfare: 'Thoroughfare',
    post_code: 'PostCode', post_city_name: 'PostCityName',
  }.freeze

  def providers = @read

  attr_reader :data_services

  private

  # `DSD:ERR:0005` asks a question instead of refusing, so it comes back as an
  # error of its own carrying that question. The other five codes of the
  # chapter keep the class they had.
  #
  # A code arriving without a question to ask leaves nothing to ask the user:
  # it is then said as the ordinary refusal it has become, rather than as a
  # question with no wording.
  def refusal_error(exception, code)
    return super unless code == UserAttributesRequired::CODE

    classifications = requested_classifications(exception)
    return super if classifications.empty?

    UserAttributesRequired.new(refusal(exception, code), classifications:)
  end

  # All the questions or none of them. A slot absent breaks `R-DSD-ERR-S022`
  # and an element carrying no concept breaks `S019`; either way the directory
  # is outside its own rules, and a partial set disambiguates nothing — the
  # answers would be reissued only to be refused again. Trimming what could be
  # read would hand the caller a questionnaire with holes it cannot see.
  #
  # Read from the node `find_slot` returns rather than through `slot_elements`,
  # which raises on a missing slot: a directory breaking its own rule is not a
  # message this application could not read.
  def requested_classifications(exception)
    found = find_slot(CLASSIFICATION_CONCEPTS, exception)
    return [] if found.nil?

    concepts = all(found, './rim:SlotValue/rim:Element')
      .map { |element| at(element, './sdg:EvidenceProviderClassification') }

    return [] if concepts.any?(&:nil?)

    concepts.map { |concept| build_classification(concept) }
  end

  # `sdg:Type` is lower-cased before being kept: `R-DSD-ERR-C031` fixes its
  # three values in lower case, and the three `DSD-ERR005` examples of the
  # 2.0.1 corpus — `schematron-validator/…/DSD-ERR/valid/` — all write
  # `Codelist`, under `valid/` and against the rules published beside them.
  # Nothing reissues the case as received: the reissued directory query of
  # § 4.2.2 carries the identifier of the concept and nothing else. The slot
  # of chapter 4.5.1 is another matter, `R-EDM-REQ-C020` making `sdg:Type`
  # mandatory there — OOTS-53's, and read from these rules rather than from
  # what was received.
  def build_classification(concept)
    identifier = at(concept, './sdg:Identifier')

    EvidenceProviderClassification.new(
      id: identifier&.text&.strip,
      # Stripped like everything else read here: `R-DSD-ERR-C033` matches on
      # `normalize-space`, so a scheme padded by the directory satisfies the
      # rule and must satisfy the reading of it.
      scheme_id: attribute(identifier, 'schemeID')&.strip,
      type: text(concept, './sdg:Type')&.downcase,
      value_expression: text(concept, './sdg:ValueExpression'),
      descriptions: by_language(all(concept, './sdg:Description')),
    )
  end

  # The providers are what `@read` holds, so that an answer whose records carry
  # no access service is still rejected as unreadable — `R-DSD-RESP-S014` makes
  # `sdg:AccessService` mandatory.
  def read
    @data_services = records(DATA_SERVICE).map { |declared| build_service(declared) }
    @data_services.flat_map(&:providers)
  end

  def build_service(declared)
    DataService.new(
      id: text(declared, './sdg:Identifier'),
      evidence_type_classification: text(declared, './sdg:EvidenceTypeClassification'),
      **distributed_as(at(declared, './sdg:DistributedAs')),
      level_of_assurance: text(declared, './sdg:AuthenticationLevelOfAssurance'),
      descriptions: by_language(all(declared, './sdg:Title')),
      details: by_language(all(declared, './sdg:Description')),
      providers: all(declared, './sdg:AccessService').map { |service| build(service) },
    )
  end

  # Read from one and the same distribution, and not each from the record: a
  # directory publishes several, which is what R-DSD-RESP-C039 and C041 are
  # written around, and a path anchored higher would take the format of the
  # first and the data model of another — a request asking for a PDF against an
  # XML schema, which nothing downstream would question. Asking for more than
  # one distribution is OOTS-129's.
  def distributed_as(published)
    return {} if published.nil?

    {
      distribution_format: text(published, './sdg:Format'),
      distribution_language: text(published, './sdg:Language'),
      distribution_conforms_to: text(published, './sdg:ConformsTo'),
    }
  end

  def build(service)
    publisher = at(service, './sdg:Publisher')

    EvidenceProvider.new(
      identifier: identity(publisher, :announced_provider_identity),
      access_point: access_point(service),
      descriptions: by_language(all(publisher || service, './sdg:Name')),
      address: address(publisher),
    ).validate!(:announced_provider, error: CommonServicesError)
  end

  def identity(scope, subject)
    identifier = scope && at(scope, './sdg:Identifier')

    EbmsIdentity.new(id: identifier&.text&.strip, type_id: attribute(identifier, 'schemeID'))
      .validate!(subject, error: CommonServicesError)
  end

  # `ConformsTo` names the EDM versions the gateway speaks, and is what the
  # `specification` parameter of the query filters on: a service absent from an
  # answer may well exist and speak another version.
  def access_point(service)
    identifier = at(service, './sdg:Identifier')

    AccessPoint.new(
      id: identifier&.text&.strip,
      type_id: attribute(identifier, 'schemeID'),
      descriptions: by_language(all(service, './sdg:Name')),
      conforms_to: all(service, './sdg:ConformsTo').map { |version| version.text.strip },
    ).validate!(:announced_access_point, error: CommonServicesError)
  end

  # Read and validated rather than left to its default, which is France: the
  # provider this describes is a foreign one, and silently calling it French
  # would put the wrong country in the message built from it. Only the country
  # is required of an address, and only it is validated.
  def address(publisher)
    found = publisher && at(publisher, './sdg:Address')
    written = ADDRESS_LINES.transform_values { |element| found && text(found, "./sdg:#{element}") }

    Address.new(**written)
      .validate!(:announced_provider_address, error: CommonServicesError)
  end
end
