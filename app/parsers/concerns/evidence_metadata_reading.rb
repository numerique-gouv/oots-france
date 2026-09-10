# What a received `ExecuteQueryResponse` says of the evidence it carries: the
# identifier of chapter 4.8, and the subject the provider confirms having
# matched. Both live in the `EvidenceMetadata` slot, and where that slot sits
# depends on the line the response is written on.
#
# Apart from the parser, as `AgentConformance` and `RequirementConformance` are
# apart from the request's: `EvidenceResponseParser` carries the rules of
# chapter 4.6 for a whole response, and tripped `Metrics/ClassLength` the day
# the second place to look for the metadata landed beside them.
#
# Everything read here is nil-tolerant and never validated: no error path runs
# from a portal back to a provider, so refusing an otherwise deliverable
# response over a journal field would destroy a valid exchange and tell nobody.
# `AuditTrail#readable` then keeps the partial subject an auditor most wants to
# see — a subject the provider cut short being exactly the departure worth
# reading.
#
# `response` and `specification` are the includer's.
module EvidenceMetadataReading
  include OotsNamespaces

  # The `MainEvidence` classification node of `R-EDM-RESP-S062`: in 2.0.1 the
  # objects of the list are wrapped in a `rim:RegistryPackageType`, and the
  # classification is what tells the document apart from the annexes beside it.
  MAIN_EVIDENCE = './rim:RegistryObjectList/rim:RegistryObject/rim:RegistryObjectList/rim:RegistryObject' \
                  "[rim:Classification/@classificationNode='MainEvidence']".freeze

  # Where the same block sits on the 1.2 line: `R-EDM-RESP-S015` anchors on the
  # objects of the list itself there, and there is nothing to classify — a 1.2
  # response carries one document, and no rule of that line names `MainEvidence`.
  FLAT_EVIDENCE = './rim:RegistryObjectList/rim:RegistryObject'.freeze

  EVIDENCE_METADATA = "./rim:Slot[@name='EvidenceMetadata']/rim:SlotValue/sdg:Evidence".freeze

  # « Evidence Identifier (for evidence response) » of chapter 4.8, taken from
  # the `Identifier` of the metadata block.
  def evidence_identifier
    metadata = evidence_metadata

    text_at(metadata, './sdg:Identifier') if metadata
  end

  # The subject the provider confirms having matched. Chapter 4.5.2 gives
  # `sdg:IsAbout` that role — « Must contain the Minimum Data Set part of the
  # Evidence Subject attributes of the Evidence Request to confirm identity
  # matching » — and the journal keeps it beside the subject the request asked
  # for, which it is allowed to differ from.
  #
  # What binds a receiver to keep it is the sentence opening §3.2 of chapter
  # 4.8: « the information included in the evidence response, with the exception
  # of the evidence itself, must be logged ». Its tables settle nothing either
  # way — each announces itself as a list of identifiers enabling correlation,
  # and of the six elements `R-EDM-RESP-S062` puts in this block the only one
  # they name is the identifier above, under a business name rather than an XML
  # one.
  #
  # An `xs:choice`, under `R-EDM-RESP-S041` and `-S042`. Reaching for the two
  # branches rather than for the choice is what makes an empty `sdg:IsAbout`
  # read as no subject, instead of a person carrying no field at all.
  def evidence_subject
    metadata = evidence_metadata
    return if metadata.nil?

    person = at(metadata, './sdg:IsAbout/sdg:NaturalPerson')
    return natural_subject(person) if person

    organisation = at(metadata, './sdg:IsAbout/sdg:LegalPerson')

    legal_subject(organisation) if organisation
  end

  private

  def evidence_metadata = at(response, "#{evidence_object}/#{EVIDENCE_METADATA}")

  def evidence_object = specification.packaged_response? ? MAIN_EVIDENCE : FLAT_EVIDENCE

  # `R-EDM-RESP-S041`, whose closed list is not the request's: there a natural
  # person travels as an `sdg:Person` under a `NaturalPerson` slot, here as an
  # `sdg:NaturalPerson` under `sdg:IsAbout`. The organisation below keeps one
  # name on both sides.
  #
  # The five elements the rule lists and no more: a response carries neither the
  # level of assurance nor the sex a request may, so a subject read here is
  # thinner than the one France sent — which is what the journal must show of
  # what the correspondent actually confirmed.
  def natural_subject(person)
    NaturalPerson.new(
      eidas_identifier: text_at(person, './sdg:Identifier'),
      family_name: text_at(person, './sdg:FamilyName'),
      given_name: text_at(person, './sdg:GivenName'),
      date_of_birth: text_at(person, './sdg:DateOfBirth'),
      place_of_birth: text_at(person, './sdg:PlaceOfBirth'),
    )
  end

  # `R-EDM-RESP-S042` (FATAL), far narrower than the `sdg:LegalPerson` of a
  # request: the eIDAS identifier and the legal name, and nothing besides — the
  # optional sectoral identifiers of chapter 4.5.1 among what it excludes.
  # Reading those here would file identifiers a conformant response never
  # carries.
  #
  # A correspondent that sends one anyway breaks the rule, and nothing says so:
  # `violations` carries no rule about the content of `sdg:IsAbout`, so the
  # departure leaves the identifier dropped and the `detail` column empty. That
  # gap is older than this reading — nothing read the element at all — and
  # closing it belongs where the rules of chapter 4.6 live, not here.
  def legal_subject(organisation)
    LegalPerson.new(
      eidas_identifier: text_at(organisation, './sdg:LegalPersonIdentifier'),
      legal_name: text_at(organisation, './sdg:LegalName'),
    )
  end
end
