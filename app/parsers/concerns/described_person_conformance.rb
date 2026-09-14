# What chapter 4.6 asks of each person a received request describes: the subject
# of the evidence, natural or legal, and the authorised representative acting
# for them, natural or legal. Four slots of `query:Query`, and one battery of
# rules published four times over.
#
# The symmetry is the family, and it is total. `C058`/`C059` are `C036`/`C037`,
# `C061` is `C040`, `C062`/`C063` are `C041`/`C042`, `C064` is `C043`,
# `C078`/`C079`/`C080` are `C075`/`C076`/`C077`; and on the legal side `C082` to
# `C089` are `C047` to `C055`, one for one. The chapter publishes one assertion
# under two identifiers because it is the *slot* that fixes which, never the
# person — which is why the readers below are tables keyed by slot rather than a
# method per rule, the shape `RegRepShapeConformance` uses for the same reason.
# Two asymmetries survive it: `C056` judges an `sdg:RegisteredAddress` where its
# twin `C090` judges an `sdg:CurrentAddress`, and the natural representative
# carries rules on its sex and on its sectoral attributes that no subject has.
#
# **Judged, and read for nothing else.** France does not model the
# representative, nor the address, nationality or level of assurance of an
# organisation: it refuses what breaks a rule and ignores the rest. That is what
# separates this module from the twins it does not hold — `C036`, `C037` and
# `C043` live in `NaturalPerson`, `C049`, `C054` and `C055` in `LegalPerson`,
# and `C040`, `C041`, `C042` and `C051` in `EchoedValueConformance`, because
# each of those values is read into something France keeps or copies out. The
# rule is the same; what differs is whether anything but the refusal depends on
# it.
#
# Apart from the parser, as the nine conformance modules beside it are, and for
# the reason `RequirementConformance` states: the class does not fit the rules
# of an eleventh subject.
#
# Refusals go through `refuse`, which the parser including this defines.
module DescribedPersonConformance
  include OotsNamespaces

  # Where each of the four sits, written from `query:Query` down. The subject's
  # two are read elsewhere as well; the representative's two are read nowhere
  # else at all.
  SUBJECT = "./rim:Slot[@name='NaturalPerson']/rim:SlotValue/sdg:Person".freeze
  LEGAL_SUBJECT = "./rim:Slot[@name='LegalPerson']/rim:SlotValue/sdg:LegalPerson".freeze
  REPRESENTATIVE = "./rim:Slot[@name='AuthorizedRepresentative']/rim:SlotValue/sdg:Person".freeze
  LEGAL_REPRESENTATIVE = "./rim:Slot[@name='AuthorizedRepresentativeLegalPerson']/rim:SlotValue/sdg:LegalPerson".freeze

  # The ten rules that hold an element to the `CountryIdentificationCode` list,
  # keyed by where each finds its context nodes. One assertion, ten identifiers,
  # and the slot is what says which — `C015` reads that same assertion over an
  # agent's address, and `CountryIdentificationCode` holds why the comparison is
  # exact.
  #
  # Every context is the element itself, so an absent one triggers nothing: no
  # rule of the chapter requires a nationality, a country of birth or an
  # address of anybody here.
  #
  # `C090` is in the table though the schema gives `sdg:LegalPerson` no
  # `sdg:CurrentAddress` — only an `sdg:RegisteredAddress`, which is what its
  # twin `C056` judges on the subject. Applied to the letter rather than
  # transposed onto the element the schema does admit: the rule as published
  # fires on nothing a schema-valid request carries, and moving it would be
  # inventing one.
  COUNTRY_CODES = {
    "#{SUBJECT}/sdg:CurrentAddress/sdg:AdminUnitLevel1" => 'R-EDM-REQ-C045',
    "#{SUBJECT}/sdg:Nationality" => 'R-EDM-REQ-C075',
    "#{SUBJECT}/sdg:CountryOfBirth" => 'R-EDM-REQ-C076',
    "#{SUBJECT}/sdg:CountryOfResidence" => 'R-EDM-REQ-C077',
    "#{LEGAL_SUBJECT}/sdg:RegisteredAddress/sdg:AdminUnitLevel1" => 'R-EDM-REQ-C056',
    "#{REPRESENTATIVE}/sdg:CurrentAddress/sdg:AdminUnitLevel1" => 'R-EDM-REQ-C067',
    "#{REPRESENTATIVE}/sdg:Nationality" => 'R-EDM-REQ-C078',
    "#{REPRESENTATIVE}/sdg:CountryOfBirth" => 'R-EDM-REQ-C079',
    "#{REPRESENTATIVE}/sdg:CountryOfResidence" => 'R-EDM-REQ-C080',
    "#{LEGAL_REPRESENTATIVE}/sdg:CurrentAddress/sdg:AdminUnitLevel1" => 'R-EDM-REQ-C090',
  }.freeze

  # « The level of assurance is there, and it is one of the three the list
  # publishes », three times: the pair `C036`/`C037` already asks it of the
  # natural subject, where `NaturalPerson` answers for it.
  #
  # The first of each pair has the person for context and tests
  # `not(normalize-space(sdg:LevelOfAssurance)='')`, so an absent element breaks
  # it as much as a blank one; the second has the element, and never fires when
  # there is none.
  LEVELS_OF_ASSURANCE = {
    LEGAL_SUBJECT => { required: 'R-EDM-REQ-C047', listed: 'R-EDM-REQ-C048' }.freeze,
    REPRESENTATIVE => { required: 'R-EDM-REQ-C058', listed: 'R-EDM-REQ-C059' }.freeze,
    LEGAL_REPRESENTATIVE => { required: 'R-EDM-REQ-C082', listed: 'R-EDM-REQ-C083' }.freeze,
  }.freeze

  # « The identifier names its scheme, and that scheme is `eidas` », three
  # times: the pair `C041`/`C042` asks it of the natural subject, where
  # `EchoedValueConformance` answers for it because `C040`'s context is what the
  # scheme decides.
  #
  # Both of each pair have the identifier element for context, so a person
  # carrying none breaks neither — chapter 2.1 §2.3.1.2 provides for an identity
  # established in the requester's own country. The first tests `@schemeID`, the
  # bare existence of the attribute, so one written empty satisfies it and falls
  # to the second.
  #
  # This is what makes the `eidas2` branch unreachable: `C121`, `C122`, `C123`,
  # `C125` and `C127` all narrow their context to a representative whose
  # identifier declares `eidas2`, which `C063` refuses first. Its message says
  # that value « can be used for testing purposes »; its assertion does not, and
  # the assertion is what plays — the reading `C042` already gets.
  EIDAS_SCHEMES = {
    "#{LEGAL_SUBJECT}/sdg:LegalPersonIdentifier" =>
      { required: 'R-EDM-REQ-C052', fixed: 'R-EDM-REQ-C053' }.freeze,
    "#{REPRESENTATIVE}/sdg:Identifier" =>
      { required: 'R-EDM-REQ-C062', fixed: 'R-EDM-REQ-C063' }.freeze,
    "#{LEGAL_REPRESENTATIVE}/sdg:LegalPersonIdentifier" =>
      { required: 'R-EDM-REQ-C086', fixed: 'R-EDM-REQ-C087' }.freeze,
  }.freeze

  # `C061` and `C085`, the representative's halves of the assertion `C040` and
  # `C051` make of the subject's identifier — `IdentifierScheme::EIDAS_IDENTIFIER`
  # is that assertion, transcribed once beside the code list it is built from,
  # and read from there by this module and by `EchoedValueConformance` alike.
  #
  # The 1.2 line writes both differently and neither difference can change an
  # outcome, which is why no predicate of `EdmSpecification` guards them:
  # `EEA_Country` is the same thirty-one codes as `OOTS_Country` under another
  # name, and `C061`'s context there carries no `[@schemeID='eidas']` predicate,
  # so it reaches every identifier — but `C063` is identical on both lines and
  # has already refused every scheme but `eidas`. A guard here would be a branch
  # nothing could ever take.
  EIDAS_IDENTIFIERS = {
    "#{REPRESENTATIVE}/sdg:Identifier[@schemeID='eidas']" => 'R-EDM-REQ-C061',
    "#{LEGAL_REPRESENTATIVE}/sdg:LegalPersonIdentifier" => 'R-EDM-REQ-C085',
  }.freeze

  # `R-EDM-REQ-C126`: under an `eidas` identifier, the sex is one of the three
  # values the eIDAS profile of the `Gender` list publishes — which is
  # `NaturalPerson::GENDERS`.
  EIDAS_GENDERS = NaturalPerson::GENDERS

  # The scope of a power of representation, said in procedures: `C081` and
  # `C091` admit a code of the `Procedures` list, or `00` beside it.
  ADMITTED_PROCEDURES = (ProcedureCode::PUBLISHED + [ProcedureCode::SYSTEM_CHECK]).freeze

  # `R-EDM-REQ-C091` splits on this, a regular expression and not a literal:
  # `tokenize($attrval, ',\s*')`.
  PROCEDURE_SEPARATOR = /,\s*/

  private

  # One entry point among the checks of `validate!`, and the scheme of the
  # identifiers first of all: `C063` is what empties the `eidas2` branch, and
  # `C061`'s context is narrowed by the very scheme it refuses. Everything after
  # it judges an identifier that names `eidas` or no identifier at all. No rule
  # of the chapter fixes the rest of the order, nor where this sits among the
  # checks of `validate!`.
  def require_conformant_described_persons
    require_eidas_schemes
    require_eidas_identifiers
    require_declared_levels_of_assurance
    require_country_codes
    require_representative_identity
    require_representative_organisation
  end

  def require_eidas_schemes
    EIDAS_SCHEMES.each do |path, rules|
      all(query, path).each do |identifier|
        scheme = attribute(identifier, 'schemeID')
        refuse(rules.fetch(:required), 'parsers.evidence_request.person_identifier_without_scheme') if scheme.nil?
        next if scheme == IdentifierScheme::EIDAS

        refuse(rules.fetch(:fixed), 'parsers.evidence_request.person_scheme_unexpected',
          scheme:, expected: IdentifierScheme::EIDAS)
      end
    end
  end

  # The value is read raw: the assertions normalise nothing, and their missing
  # `^` is what admits a leading blank — the reading
  # `EchoedValueConformance#require_conformant_subject_identifiers` states.
  def require_eidas_identifiers
    EIDAS_IDENTIFIERS.each do |path, rule|
      all(query, path).each do |identifier|
        next if identifier.text.match?(IdentifierScheme::EIDAS_IDENTIFIER)

        refuse(rule, 'parsers.evidence_request.person_identifier_country_unknown',
          identifier: identifier.text.presence || I18n.t('parsers.evidence_request.unnamed_person_identifier'))
      end
    end
  end

  def require_declared_levels_of_assurance
    LEVELS_OF_ASSURANCE.each do |path, rules|
      all(query, path).each do |person|
        declared = text_at(person, './sdg:LevelOfAssurance')
        refuse(rules.fetch(:required), 'parsers.evidence_request.person_without_level_of_assurance') if declared.to_s.squish.empty?
        next if NaturalPerson::LEVELS_OF_ASSURANCE.include?(declared)

        refuse(rules.fetch(:listed), 'parsers.evidence_request.person_level_of_assurance_unknown',
          level: declared, admitted: NaturalPerson::LEVELS_OF_ASSURANCE.join(', '))
      end
    end
  end

  def require_country_codes
    COUNTRY_CODES.each do |path, rule|
      all(query, path).each do |code|
        next if CountryIdentificationCode.valid?(code.text)

        refuse(rule, 'parsers.evidence_request.person_country_unknown',
          country: code.text.presence || I18n.t('parsers.evidence_request.unnamed_country'))
      end
    end
  end

  # What the natural representative carries and no subject does: its date of
  # birth, its sex, and the procedures its power of representation covers.
  def require_representative_identity
    all(query, REPRESENTATIVE).each do |person|
      require_dates_of_birth(person)
      require_genders(person)
      require_procedures(person, 'R-EDM-REQ-C081') { |value| [value] }
    end
  end

  # `R-EDM-REQ-C064`, the representative's half of `C043` — one assertion, two
  # identifiers, and `NaturalPerson::DATE_OF_BIRTH` is the shape it asks for,
  # transcribed where the subject's own validation already needed it. Anchored
  # at both ends, where `C002` is anchored at neither, and applied to
  # `normalize-space(text())`, which `squish` is.
  def require_dates_of_birth(person)
    all(person, './sdg:DateOfBirth').each do |date|
      next if date.text.squish.match?(NaturalPerson::DATE_OF_BIRTH)

      refuse('R-EDM-REQ-C064', 'parsers.evidence_request.representative_date_of_birth_malformed',
        date: date.text.squish.presence || I18n.t('parsers.evidence_request.unnamed_date'))
    end
  end

  # `C124` judges every `sdg:Gender` the representative carries, whatever scheme
  # its identifier names, against the `Gender` list whole. `C126` narrows itself
  # to a representative identified under `eidas` and tests `sdg:Gender=('Male',
  # 'Female','Unspecified')` — an assertion on the *person*, which an absent
  # element fails, `() = (…)` being false. Its published sentence only
  # constrains a value; the assertion also requires one, and the assertion is
  # what plays, as it is for `C042`. `docs/carte_des_tdd.md` records the
  # disagreement.
  #
  # Neither exists on the 1.2 line, so a 1.2 request writes that element as it
  # likes — `EdmSpecification#representative_gender?` is what says so.
  def require_genders(person)
    return unless specification.representative_gender?

    require_published_genders(person)
    require_eidas_gender(person)
  end

  def require_published_genders(person)
    all(person, './sdg:Gender').each do |gender|
      next if NaturalPerson::GENDER_CODES.include?(gender.text)

      refuse('R-EDM-REQ-C124', 'parsers.evidence_request.representative_gender_unknown',
        gender: gender.text.presence || I18n.t('parsers.evidence_request.unnamed_gender'),
        admitted: NaturalPerson::GENDER_CODES.join(', '))
    end
  end

  def require_eidas_gender(person)
    return unless at(person, "./sdg:Identifier[@schemeID='#{IdentifierScheme::EIDAS}']")
    return if all(person, './sdg:Gender').any? { |gender| EIDAS_GENDERS.include?(gender.text) }

    refuse('R-EDM-REQ-C126', 'parsers.evidence_request.representative_gender_outside_eidas',
      admitted: EIDAS_GENDERS.join(', '))
  end

  # What the legal representative carries and the legal subject does not: a
  # `sdg:LegalPersonIdentifier` whose value is required outright, and optional
  # `sdg:Identifier` elements whose scheme the `IdentifierSchemes` list holds.
  #
  # `C084` has the organisation for context and tests
  # `not(normalize-space(sdg:LegalPersonIdentifier)='')`, so it is the absence
  # that breaks it — where its twin `C049` asks the same of the subject and
  # `LegalPerson` answers for that one.
  def require_representative_organisation
    all(query, LEGAL_REPRESENTATIVE).each do |organisation|
      require_legal_person_identifier(organisation)
      require_published_identifier_schemes(organisation)
      require_procedures(organisation, 'R-EDM-REQ-C091') { |value| value.split(PROCEDURE_SEPARATOR) }
    end
  end

  def require_legal_person_identifier(organisation)
    return if text_at(organisation, './sdg:LegalPersonIdentifier').to_s.squish.present?

    refuse('R-EDM-REQ-C084', 'parsers.evidence_request.representative_without_identifier')
  end

  # `C088` asserts the attribute's presence and `C089` has that attribute for
  # context, so an absent one never reaches the second — the shape `C054` and
  # `C055` take on the subject, where `LegalPerson` answers for them.
  def require_published_identifier_schemes(organisation)
    all(organisation, './sdg:Identifier').each do |identifier|
      scheme = attribute(identifier, 'schemeID')
      refuse('R-EDM-REQ-C088', 'parsers.evidence_request.representative_identifier_without_scheme') if scheme.nil?
      next if IdentifierScheme::LEGAL_PERSON.include?(scheme)

      refuse('R-EDM-REQ-C089', 'parsers.evidence_request.representative_scheme_unpublished',
        scheme:, admitted: IdentifierScheme::LEGAL_PERSON.join(', '))
    end
  end

  # `C081` and `C091` differ in how they read one `sdg:AttributeValue`, and the
  # block is that difference. `C081` compares the value **whole** — `or` being
  # the loosest operator of XPath, its assertion reads « the value is a code, or
  # the value is `00` » — so `T1,T3` breaks it, whatever its message says about
  # comma-separated values. `C091` does split, on `,\s*`.
  #
  # `C091` is also the one rule of this module that is not executable as
  # published: its `sch:let` binds `$attrval` to *every* `sdg:AttributeValue` of
  # the slot, and `tokenize()` takes a single string, so an organisation naming
  # two sectoral attributes is a type error rather than a verdict. France judges
  # each value for itself, which is what the assertion does wherever it runs at
  # all. `docs/carte_des_tdd.md` records it.
  #
  # Neither rule filters on the URI of the attribute, though both messages name
  # `PowerOfRepresentationScope`: the contexts stop at `sdg:AttributeValue`, so
  # every sectoral attribute is judged. The assertion, not its message.
  def require_procedures(person, rule)
    all(person, './sdg:SectorSpecificAttribute/sdg:AttributeValue').each do |attribute|
      unpublished = yield(attribute.text).reject { |value| ADMITTED_PROCEDURES.include?(value) }
      next if unpublished.empty?

      refuse(rule, 'parsers.evidence_request.representative_procedure_unpublished',
        procedures: unpublished.join(', '))
    end
  end
end
