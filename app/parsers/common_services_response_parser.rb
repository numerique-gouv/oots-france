# The envelope every Common Services answer shares (chapter 3.6.2).
#
# The HTTP status says nothing: success and refusal both arrive as 200, and the
# specification requires the body to be read whatever the code. What decides is
# `query:QueryResponse/@status`, and a refusal names itself in the `code` of
# its `rs:Exception` — `EB:ERR:0001`, `DSD:ERR:0005`…
class CommonServicesResponseParser
  include SlotReading

  SUCCESS = 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success'.freeze

  # Both Evidence Broker queries of chapter 3.2.4 echo the same slot: one
  # answers the requirements of a procedure, the other the evidence types that
  # satisfy one of them, and each wraps its record in a `sdg:Requirement`.
  REQUIREMENT = "./rim:Slot[@name='Requirement']/rim:SlotValue/sdg:Requirement".freeze

  def initialize(body)
    @response = at(Nokogiri::XML(body), '/query:QueryResponse')
    raise CommonServicesError, I18n.t('parsers.common_services_response.not_a_query_response') if @response.nil?

    reject_unless_expected_version
    reject_unless_successful
    @read = read
    reject_unless_read_something
  end

  private

  # What each subclass makes of the records. Read at construction, and not when
  # the caller first asks: an answer whose envelope is sound but whose records
  # are not is then rejected by the constructor like any other, which is what
  # lets a caller cache a body on the strength of having built one.
  #
  # A subclass needing state of its own must set it *before* `super`, this
  # running from the parent constructor — the natural order, `super` first,
  # would read it while it is still nil.
  def read = nil

  # Chapter 3.6.2 has the service echo the version it answered in. It answers
  # in the v1.0 shape — which carries no such slot — when **no `Accept-Version`
  # reaches it**, and refuses with an invalid-request exception when it supports
  # none of the versions asked for. This client always sends the header, so what
  # is guarded here is anything that strips or ignores it on the way, and a
  # directory answering off-contract: unchecked, such an answer reads as a
  # success whose slots are all missing, which every parser below would report
  # as « this country has no such evidence » rather than « we did not speak ».
  def reject_unless_expected_version
    announced = text(response, "./rim:Slot[@name='SpecificationIdentifier']/rim:SlotValue/rim:Value")
    return if announced == CommonServicesSpecification::IDENTIFIER

    raise CommonServicesError,
      I18n.t('parsers.common_services_response.unexpected_version',
        announced: announced.presence || I18n.t('parsers.common_services_response.unnamed_version'),
        expected: CommonServicesSpecification::IDENTIFIER)
  end

  attr_reader :response

  def reject_unless_successful
    return if attribute(response, 'status') == SUCCESS

    exception = at(response, './rs:Exception')
    raise CommonServicesError, I18n.t('parsers.common_services_response.refused_without_reason') if exception.nil?

    code = attribute(exception, 'code').presence

    raise CommonServicesError.new(refusal(exception, code), code:)
  end

  # Both chapters make `message` mandatory (R-DSD-ERR-C020, R-EB-ERR-013) and
  # only the Evidence Broker makes `code` optional. The fallback is therefore
  # for a directory not honouring its own schema, which no rule forbids it
  # from doing, and without which such a refusal would carry an empty message.
  def refusal(exception, code)
    said = [code, attribute(exception, 'message')].compact_blank.join(' : ')

    said.presence || I18n.t('parsers.common_services_response.refused', detail: exception.to_xml.squish)
  end

  def registry_objects = all(response, './rim:RegistryObjectList/rim:RegistryObject')

  def records(path) = registry_objects.filter_map { |object| at(object, path) }

  # Holding nothing is not something a directory says by succeeding: it answers
  # `EB:ERR:0001` or `DSD:ERR:0001` — « the result set is empty » — which is a
  # refusal, rejected above. A success that yields nothing is therefore an
  # answer we failed to read, whatever the depth at which reading gave out, and
  # saying so is what keeps « we could not read this » from reaching the caller
  # as « this country has nothing ».
  #
  # The rule bears on the answer as a whole, which is the level the codes above
  # describe. Two limits follow, both deliberate. A record that publishes no
  # access service breaks `R-DSD-RESP-S014`, which makes `sdg:AccessService`
  # mandatory, so an answer made only of those is reported here as unreadable
  # rather than as a country without a provider — a correspondent is not
  # obliged to honour the rule, and no captured response shows one. And a
  # record that yields nothing while its neighbours yield something is absorbed
  # by the whole, which no rule of the TDD forbids.
  def reject_unless_read_something
    return unless @read.is_a?(Enumerable) && @read.none?

    raise CommonServicesError,
      I18n.t('parsers.common_services_response.nothing_readable', count: registry_objects.size)
  end

  # What the directories publish is indented, so every reading of an element's
  # text is followed by the same strip.
  def text(scope, path) = text_at(scope, path)&.strip

  # `lang` is an attribute of the SDG profile, not `xml:lang`, so it is read
  # without a namespace.
  def by_language(nodes)
    nodes.to_h { |node| [attribute(node, 'lang'), node.text.strip] }
  end
end
