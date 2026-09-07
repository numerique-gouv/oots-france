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
  SYSTEM_CHECK = '00'.freeze
  STUDY_FINANCING = 'T1'.freeze
  BIRTH_REGISTRATION = 'R1'.freeze
  DIPLOMA_RECOGNITION = 'T3'.freeze
end
