# The data services holding an evidence type in a country, as the Data Service
# Directory returns them (chapter 3.1.4).
#
# `sdg:AccessService/sdg:Identifier` is the ebCore party identifier of the
# gateway, and its `schemeID` the scheme naming it: OOTS runs no SMP, so
# chapter 4.7 has this identifier matched against a statically configured
# PMode, which is what says at which address the party answers.
class DataServicesResponseParser < CommonServicesResponseParser
  DATA_SERVICE = "./rim:Slot[@name='DataServiceEvidenceType']/rim:SlotValue/sdg:DataServiceEvidenceType".freeze

  ADDRESS_LINES = {
    country: 'AdminUnitLevel1', thoroughfare: 'Thoroughfare',
    post_code: 'PostCode', post_city_name: 'PostCityName',
  }.freeze

  # Chapter 3.1.4 §4.4.3.3: « For each EvidenceProviderClassification of the
  # DSD:ERR:0005 a separate answer must be provided by the user ».
  REQUESTED_CLASSIFICATIONS = "./rim:Slot[@name='UserRequestedClassificationConcepts']/rim:SlotValue/" \
                              'rim:Element/sdg:EvidenceProviderClassification'.freeze

  def providers = @read

  attr_reader :data_services

  private

  # In the order the exception writes them, which is the order the questions
  # are asked in: the chapter fixes none. Only `DSD:ERR:0005` asks any.
  def requested_classifications(exception)
    return [] unless attribute(exception, 'code') == ProviderClassificationRequired::CODE

    all(exception, REQUESTED_CLASSIFICATIONS).map { |classification| build_classification(classification) }
  end

  # What a classification says of itself, whether the directory asks it or
  # publishes it with the value a service matched (chapter 3.1.4 §4.3.2).
  def build_classification(classification)
    identifier = at(classification, './sdg:Identifier')

    EvidenceProviderClassification.new(
      id: identifier&.text&.strip,
      scheme_id: attribute(identifier, 'schemeID'),
      type: text(classification, './sdg:Type'),
      value_expression: text(classification, './sdg:ValueExpression'),
      descriptions: by_language(all(classification, './sdg:Description')),
      supported_value: supported_value(classification),
    )
  end

  # `sdg:StringValue` or `sdg:BooleanValue`, whichever the directory published.
  def supported_value(classification)
    text(classification, './sdg:SupportedValue/sdg:StringValue') ||
      text(classification, './sdg:SupportedValue/sdg:BooleanValue')
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
      **distributed_as(declared),
      distribution_formats: formats_of(declared),
      level_of_assurance: text(declared, './sdg:AuthenticationLevelOfAssurance'),
      descriptions: by_language(all(declared, './sdg:Title')),
      details: by_language(all(declared, './sdg:Description')),
      providers: all(declared, './sdg:AccessService').map { |service| build(service) },
      classifications: all(declared, './sdg:EvidenceProviderClassification').map { |found| build_classification(found) },
    )
  end

  # Read from one and the same distribution, the one
  # `DataService.requested_format` picks, and not each from the record: chapter
  # 4.5.1 §3.5 has only « distributions which the data service is able to
  # provide » requested, and a path anchored higher would take the format of
  # one and the data model of another — a request asking for a PDF against an
  # XML schema, which nothing downstream would question.
  #
  # Both branches state what was read, the absent element included: R-DSD-RESP-S027
  # makes it mandatory, so its absence is the directory departing from the
  # specification and not a value left empty — a difference `text` cannot carry,
  # answering nil for either.
  def distributed_as(declared)
    distributions = all(declared, './sdg:DistributedAs')
    return { distribution_published: false } if distributions.empty?

    requested = DataService.requested_format(formats_of(declared))
    published = distributions.find { |distribution| text(distribution, './sdg:Format') == requested }

    {
      distribution_published: true,
      distribution_format: text(published, './sdg:Format'),
      distribution_language: text(published, './sdg:Language'),
      distribution_conforms_to: text(published, './sdg:ConformsTo'),
    }
  end

  # The format of each distribution, in the order the directory publishes them;
  # one naming none offers nothing to choose.
  def formats_of(declared) = all(declared, './sdg:DistributedAs/sdg:Format').map { |format| format.text.strip }

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
