# The procedure codes this deployment answers to.
#
# Codes of `Procedures-CodeList.gc`. None of their labels is written down here:
# `CodeListClient` reads them from that same file at run time, so nothing has to
# be kept in step with a release by hand.
#
# `00` is the OOTS system check, and the only one for which France returns an
# actual piece of evidence today. `R1` is the one it answers with a deferral
# instead — a stub, tracked as OOTS-82. `T3` is declared so the end-to-end
# scenario can exercise the refusal path: any code other than those two gets
# an `EDM:ERR:0004` back. It is the recognition of diplomas, not the
# study financing an earlier reading took it for — that one is `T1`.
module ProcedureCode
  SYSTEM_CHECK = '00'.freeze
  BIRTH_REGISTRATION = 'R1'.freeze
  DIPLOMA_RECOGNITION = 'T3'.freeze
end
