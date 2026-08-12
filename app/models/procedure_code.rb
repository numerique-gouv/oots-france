# The procedure codes this deployment answers to.
#
# `00` is the OOTS system check, and the only one for which France returns an
# actual piece of evidence today. `T3` is the student grant application of the
# TDD, declared so the end-to-end scenario can exercise the refusal path: any
# code other than `00` gets an `EDM:ERR:0004` back.
module ProcedureCode
  SYSTEM_CHECK = '00'.freeze
  STUDENT_GRANT = 'T3'.freeze
end
