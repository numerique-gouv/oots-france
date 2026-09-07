# The procedure codes this deployment names: most because it answers under
# them, `T1` because it only ever asks under it.
#
# Codes of `Procedures-CodeList.gc`. None of their labels is written down here:
# `CodeListClient` reads them from that same file at run time, so nothing has to
# be kept in step with a release by hand.
#
# `00` is the OOTS system check, and the only one for which France returns an
# actual piece of evidence today. `R1` is the one it answers with a deferral
# instead — a stub, tracked as OOTS-82. `T3` is declared so the end-to-end
# scenario can exercise the refusal path: any code other than those two gets
# an `EDM:ERR:0004` back. It is the recognition of diplomas, and not the study
# financing an earlier reading took it for.
#
# `T1` is the study financing, and the odd one out: no request is answered under
# it. It is the procedure the demonstration of the console *asks* under, the
# example chapter 1 §4.1 gives of applying for a tertiary education financing.
module ProcedureCode
  SYSTEM_CHECK = '00'.freeze
  BIRTH_REGISTRATION = 'R1'.freeze
  DIPLOMA_RECOGNITION = 'T3'.freeze
  STUDY_FINANCING = 'T1'.freeze
end
