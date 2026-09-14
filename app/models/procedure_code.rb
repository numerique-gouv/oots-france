# The procedure codes this deployment answers to.
#
# None of their labels is written down here: `CodeListClient` reads them from
# `Procedures-CodeList.gc` at run time, so nothing has to be kept in step with a
# release by hand.
#
# `00` is the OOTS system check, and the only code absent from that list:
# `R-EDM-REQ-C003` (FATAL) admits it beside the list rather than in it — "For
# testing purposes the code '00' can be used". The three others are codes of the
# list itself, so a request naming one needs no such dispensation.
#
# `T1`, the financing of studies, stands at both ends of the demonstration: it
# is the procedure the console *asks* under — the example chapter 1 §4.1 gives
# of applying for a tertiary education financing — and, beside `00`, one of the
# two France *serves*, both by the same sample document. `R1`, the registration
# of a birth, is answered with a deferral instead, so that the announcement of
# chapter 4.5.2 is produced somewhere. No chapter asks France to serve any of
# the three: they are a demonstration. Stub, tracked as OOTS-82.
#
# `T3` is the recognition of diplomas, and not the study financing an earlier
# reading took it for. It is declared so the end-to-end scenario can exercise
# the refusal path: any code other than those three gets an `EDM:ERR:0004` back.
module ProcedureCode
  # The `Procedures` code list published with the TDD, which `R-EDM-REQ-C081`
  # and `C091` hold the sectoral attributes of an authorised representative to —
  # the scope of a power of representation being said in procedures.
  #
  # Every code the list publishes, and not the three below, which are what this
  # deployment happens to answer: a correspondent naming a procedure France does
  # not serve writes a conformant request and gets an `EDM:ERR:0004`, where one
  # naming a code the specification does not publish at all breaks a FATAL rule.
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
end
