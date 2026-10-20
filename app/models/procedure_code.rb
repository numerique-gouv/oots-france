# The SDG procedure codes: the whole list the TDD publish (`PUBLISHED`), what a
# request may name (`ADMITTED`), and `R1`, the one code this deployment answers
# differently from any other.
#
# What France serves as a provider is decided on the evidence type asked for —
# `ServedEvidenceType` says which —, except under `R1`, deferred whatever the
# type. A correspondent naming a code the specification does not publish at all
# breaks a FATAL rule and gets an `EDM:ERR:0003`.
#
# None of their labels is written down here: `CodeListClient` reads them from
# `Procedures-CodeList.gc` at run time, so nothing has to be kept in step with a
# release by hand.
#
# `00` is the OOTS system check, and the only code absent from that list:
# `R-EDM-REQ-C003` (FATAL) admits it beside the list rather than in it — "For
# testing purposes the code '00' can be used". The others are codes of the list
# itself, so a request naming one needs no such dispensation.
#
# `T1` is the financing of studies, the example chapter 1 §4.1 gives of applying
# for a tertiary education financing. `R1`, the registration of a birth, is
# answered with a deferral whatever it asks for, so that the announcement of
# chapter 4.5.2 is produced somewhere: no chapter asks France for it, it is a
# demonstration. Stub, tracked as OOTS-82. `T3` is the recognition of diplomas.
module ProcedureCode
  # The `Procedures` code list published with the TDD, which `R-EDM-REQ-C081`
  # and `C091` hold the sectoral attributes of an authorised representative to —
  # the scope of a power of representation being said in procedures.
  #
  # Every code the list publishes: a correspondent naming one writes a
  # conformant request, where one naming a code the specification does not
  # publish at all breaks a FATAL rule.
  #
  # Copied here rather than read through `CodeListClient`, and compared exactly,
  # for the reasons `LanguageCode` states. `00` is beside the list and not in
  # it — both assertions add it by an alternation, as `C003` does.
  PUBLISHED = %w[
    R1 S1 T1 T2 T3 U1 U2 U3 U4 V1 V2 V3 V4 V5 W1 W2 X1 X2 X3 X4 X5 X6 X7 X9 X10 X11 AK1 AL1 AM1
  ].freeze

  SYSTEM_CHECK = '00'.freeze
  STUDY_FINANCING = 'T1'.freeze
  BIRTH_REGISTRATION = 'R1'.freeze
  DIPLOMA_RECOGNITION = 'T3'.freeze

  # What a request may name in its `Procedure` slot without breaking
  # `R-EDM-REQ-C003` (FATAL): the list, then the system check beside it — and so
  # the procedures the demonstration offers to play, in that order.
  ADMITTED = [*PUBLISHED, SYSTEM_CHECK].freeze

  def self.admitted?(code) = code.in?(ADMITTED)

  # The order the demonstration offers them in: the system check first, then
  # the codes of `declared`, then the others — each group sorted by code, `X9`
  # before `X10`.
  def self.ordered(declared:)
    others = ADMITTED - [SYSTEM_CHECK]
    first, rest = others.partition { |code| code.in?(declared) }

    [SYSTEM_CHECK, *by_code(first), *by_code(rest)]
  end

  def self.by_code(codes) = codes.sort_by { |code| [code[/\A\D*/], code[/\d+\z/].to_i] }
  private_class_method :by_code

  # The procedure France answers with the deferral of chapter 4.5.2, whatever
  # type it is asked for. Stub, tracked as OOTS-82.
  def self.deferred?(code) = code == BIRTH_REGISTRATION
end
