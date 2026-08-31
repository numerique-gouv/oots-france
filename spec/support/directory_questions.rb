# The `DSD:ERR:0005` of chapter 3.1.4, the one answer of the Data Service
# Directory that refuses nothing: the country holds several providers for the
# evidence type asked, and puts a question to the user so as to choose between
# them.
#
# Fabricated rather than captured, and apart from `Fixtures` for that reason:
# the acceptance environment publishes no such country, and the captures are
# signed over their bytes, so none of them can be edited into one. What is kept
# of the capture is its envelope — the `SpecificationIdentifier` slot above
# all, which every answer is read against.
module DirectoryQuestions
  # Through a block: in a replacement string `sub` reads `\1` and `\&` as
  # backreferences, and the exception comes from the caller.
  def data_services_asking_the_user(concepts: [classification_concept], extra_slots: '')
    common_services_answer('dsd_aucun_service_fr').first
      .sub(%r{<rs:Exception .*?/>}m) { additional_input_exception(concepts, extra_slots) }
  end

  # `R-DSD-ERR-C025` gives this code the `AdditionalInput` severity, and it
  # alone; `R-DSD-ERR-S013` makes the amputated `DataServiceEvidenceType` slot
  # mandatory beside the question, so the answer carries it even though nothing
  # reads it yet.
  def additional_input_exception(concepts, extra_slots)
    <<~XML
      <rs:Exception xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="rs:ObjectNotFoundExceptionType"
                    code="DSD:ERR:0005" message="The query requires the included extra attributes to be provided by the user"
                    severity="urn:sr.oots.tech.ec.europa.eu:codes:ErrorSeverity:DSDErrorResponse:AdditionalInput">
        <rim:Slot name="DataServiceEvidenceType">
          <rim:SlotValue xsi:type="rim:AnyValueType">
            <sdg:DataServiceEvidenceType>
              <sdg:EvidenceTypeClassification>https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FI/19f0783e-7cdc-4146-9ff9-e331514ffb74</sdg:EvidenceTypeClassification>
            </sdg:DataServiceEvidenceType>
          </rim:SlotValue>
        </rim:Slot>
        <rim:Slot name="#{DataServicesResponseParser::CLASSIFICATION_CONCEPTS}">
          <rim:SlotValue xsi:type="rim:CollectionValueType"
                         collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
            #{concepts.join}
          </rim:SlotValue>
        </rim:Slot>
        #{extra_slots}
      </rs:Exception>
    XML
  end

  # One question, wrapped as `R-DSD-ERR-S016` and `S019` have it: a
  # `rim:Element` holding a `sdg:EvidenceProviderClassification`. The default is
  # the town of birth, the case the chapter uses as its own example.
  def classification_concept(
    id: '5b8b7dbc-64e6-4b4b-9b40-fc0eb0e6a67b',
    type: 'codelist',
    scheme_id: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth',
    value_expression: 'https://sr.acc.oots.tech.ec.europa.eu/codelists/FI/TownOfBirth',
    descriptions: { 'EN' => 'In which town were you born?' }
  )
    written = descriptions.map { |lang, question| %(<sdg:Description lang="#{lang}">#{question}</sdg:Description>) }

    <<~XML
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:EvidenceProviderClassification>
          <sdg:Identifier#{scheme_id && %( schemeID="#{scheme_id}")}>#{id}</sdg:Identifier>
          #{type && "<sdg:Type>#{type}</sdg:Type>"}
          #{value_expression && "<sdg:ValueExpression>#{value_expression}</sdg:ValueExpression>"}
          #{written.join}
        </sdg:EvidenceProviderClassification>
      </rim:Element>
    XML
  end
end
