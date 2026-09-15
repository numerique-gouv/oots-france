# The version of the Evidence Data Model one message is written in.
#
# It travels twice: in the `SpecificationIdentifier` slot of every body and, in
# 2.0 alone, in the `SpecificationId` ebMS property. Chapter 4.5.1 §2.2 requires
# it to agree with the `ConformsTo` the chosen Access Service publishes in the
# DSD, so France writes what each correspondent declares rather than one version
# for everyone. `docs/versions_tdd.md` says which two lines it speaks and why
# 2.0 is the one aimed at.
#
# Every difference between the two is a predicate here, each naming the rule
# that establishes it: builders and parsers ask this object instead of comparing
# identifiers, so a third line would be added in one place.
class EdmSpecification
  # `identifier` is what a message carries. `slug` names a file, an identifier
  # being no filename — see `ApplicationBuilder#versioned`.
  attr_reader :identifier, :slug

  def initialize(identifier, slug)
    @identifier = identifier
    @slug = slug
    freeze
  end

  V2_0 = new('oots-edm:v2.0', 'v2_0')
  V1_2 = new('oots-edm:v1.2', 'v1_2')

  # The two France speaks, in order of preference. That order is the whole of
  # the choice made on emission: no chapter ranks the versions — 3.1.4 § 4.2.2,
  # 4.5.1 and 4.7 give the mechanism and the coherence constraint and no rule of
  # preference — and 2.0 is the line this repository aims at.
  SPOKEN = [V2_0, V1_2].freeze

  # Two, and never a third: `v1.0` and `v1.1` are refused at both ends.
  private_class_method :new

  def self.preferred = SPOKEN.first

  def self.find(announced) = SPOKEN.find { |spoken| spoken.identifier == announced }

  # The version a message announces where France speaks it, and the preferred
  # one where it does not. Chapter 4.7 §2.6.2 has a receiver pick its rule set
  # from what the message announces; one it cannot read leaves nothing to pick,
  # and the 2.0 rules are then what refuse the message and word the refusal.
  def self.resolve(announced) = find(announced) || preferred

  def self.identifiers = SPOKEN.map(&:identifier)

  def to_s = identifier

  # `R-EDM-ebMS-019` and `-038`, of 2.0.1 alone: the `SpecificationId` property
  # announces the version in the header, which is what lets a receiver settle
  # its rule set before opening the payload — and so refuse an unreadable one in
  # the right version (chapter 4.7 §2.6.2). A 1.2 message announces itself in
  # its `SpecificationIdentifier` slot and nowhere else.
  def announced_in_header? = self == V2_0

  # `R-EDM-ebMS-019` of 2.0.1 requires one `eb:Property` named `ExchangeId`,
  # among the four that rewriting names; the 1.2.5 rule of that same identifier
  # admits no `@name` but `originalSender` and `finalRecipient`, and so forbids
  # it. `-037` requires nothing — its context is the property itself, so it only
  # types a value already there. `docs/versions_tdd.md` tells what else the 2.0
  # header gained.
  #
  # So in 1.2 France mints an exchange identifier for itself and emits it
  # nowhere, which is what `Exchange#minted_identifier?` warns a reader of.
  def exchange_named_in_header? = self == V2_0

  # `R-EDM-REQ-S022`: the `Procedure` slot holds a `rim:InternationalStringValueType`
  # in 1.2.5 — a `rim:LocalizedString` whose `@xml:lang` `R-EDM-REQ-C004`
  # constrains — where 2.0.1 made it a plain `rim:StringValueType`. The slot
  # carries a procedure code either way, so the language is decoration.
  def translated_procedure? = self == V1_2

  # `ReturnLocation` — where a correspondent sends the user back once a preview
  # is over — is a slot of 2.0.1 alone: the name appears nowhere in the 1.2.5
  # Schematron, and `R-EDM-REQ-S061`, which types it, is published in 2.0.1
  # only. So the rule types nothing on the earlier line, rather than typing a
  # slot that line never defined.
  def return_location_slot? = self == V2_0

  # `sdg:DistributedAs` gained two elements with 2.0: the language of the
  # distribution and the documents asked for beside it. The 1.2.0 profile gives
  # it a `Format`, a `ConformsTo` and a `Transformation` and nothing else, so a
  # request naming either to a 1.2 provider would not parse there.
  def extended_distribution? = self == V2_0

  # `R-EDM-REQ-C032` counts those distributions the other way round on each
  # line: `count(sdg:DistributedAs) = 1 or count(sdg:DistributedAs) = 0` in
  # 1.2.5, « must occur not more than once », where 2.0.1 asserts `> 0`. So a
  # request asking for a structured format with a human-readable fallback
  # beside it — the case chapter 4.5.1 §3.5 names — is conformant on the later
  # line and refused on the earlier one.
  #
  # What asks for the first distribution is elsewhere, and moves the opposite
  # way: `DataServiceEvidenceTypeType` makes the element `minOccurs="1"` in the
  # 1.2.0 profile and `minOccurs="0"` in the 2.0.1 one. Neither line lets a
  # request ask for nothing, and `EvidenceRequestParser` says under what each
  # refuses it.
  def single_distribution? = self == V1_2

  # The context of `R-EDM-REQ-C092` lists twenty-three element names in 1.2.5
  # and twenty-one in 2.0.1: `sdg:JurisdictionContext` and `sdg:JurisditionLevel`
  # — spelled thus in the rule — are the two it lost. They belong to
  # `JurisdictionDeterminationType`, which the 1.2.0 profile publishes and the
  # 2.0.1 one marks « deleted in TDD version 2.0 ».
  def jurisdiction_determination? = self == V1_2

  # `R-EDM-REQ-C069` holds the `xml:lang` of `query:QueryRequest` itself to the
  # `LanguageCode` list in 1.2.5. The 2.0.1 Schematron publishes no rule of that
  # identifier at all: the language moved into `sdg:DistributedAs`, one per
  # distribution — `docs/versions_tdd.md` tells why.
  def request_language? = self == V1_2

  # `sdg:Transformation` — the subset of a conformance profile a distribution is
  # asked to follow — is an element of `EvidenceTypeDistributionType` in the
  # 1.2.0 profile alone, a transformation being a distribution of its own in
  # 2.0. `R-EDM-REQ-C035` shapes its value and `C113` cautions on it in 1.2.5
  # only; `C072`, which asks for the `sdg:ConformsTo` beside it, survives into
  # 2.0.1 on a context no schema-valid document reaches any more.
  def transformable_distribution? = self == V1_2

  # `R-EDM-REQ-C124` and `C126` hold the `sdg:Gender` of an authorised
  # representative — the first to the `Gender` code list whole, the second to
  # its three eIDAS values once the representative names an `eidas` identifier.
  # The 1.2.5 Schematron publishes neither, so a 1.2 request writes that element
  # as it likes, and a reader applying these to both lines would refuse a
  # conformant correspondent of the earlier one.
  #
  # Nothing constrains `sdg:Gender` under a `NaturalPerson` slot on either line
  # — `NaturalPerson::GENDER_CODES` says so, and `docs/carte_des_tdd.md` records
  # that chapter 4.5.1 §3.6.1 claims otherwise.
  def representative_gender? = self == V2_0

  # `R-EDM-RESP-S015` and `-S033` anchor on `rim:RegistryObjectList/rim:RegistryObject`
  # in 1.2.5, where 2.0.1 moves them one level down and adds the twenty rules
  # `-S046` to `-S066` on the `rim:RegistryPackageType` that then holds them. A
  # 2.0 response read against the 1.2.5 rules fails on `-S015` alone: its
  # top-level object is the package, and a package carries no `EvidenceMetadata`.
  def packaged_response? = self == V2_0

  # `PreviewMethod` — how the preview space an error report names is to be
  # reached — is a slot of the 1.2 line alone: the `EDM-ERR-S` of 2.0.1 notes
  # « Removed PreviewMethod », and with it go the four rules `R-EDM-ERR-C021`,
  # `-S016`, `-S025` and `-S031`. `-S027`, which closes the list of slots an
  # `rs:Exception` may carry, admits it on that line and not on this one.
  def preview_method_slot? = self == V1_2

  # `R-EDM-ERR-C024` is anchored on the `sdg:Agent` in 2.0.1 — one `sdg:Address`
  # and one `sdg:AdminUnitLevel1` in it — and on the `sdg:Address` in 1.2.5,
  # where it counts the country alone and an agent naming no address breaks
  # nothing. What the earlier line leaves unsaid, the table of chapter 4.5.3
  # §3.1 says, making that address `1..1`.
  def error_address_on_the_agent? = self == V2_0

  # Lets the `specification` column of an exchange be read and written as this
  # object rather than as the string it stores: every builder and parser serving
  # an exchange asks it its version, and a column answering a bare string would
  # have each of them look the object up again.
  #
  # An empty column is an empty version, and never the preferred one: `find` and
  # not `resolve`, whose fallback answers an announcement a *message* could not
  # be read from. A column announces nothing, and an exchange whose version was
  # never settled must not read as one conducted in 2.0.
  class Type < ActiveModel::Type::Value
    def type = :string

    def cast(value) = value.is_a?(EdmSpecification) ? value : EdmSpecification.find(value)

    def serialize(value) = cast(value)&.identifier
  end
end
