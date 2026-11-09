# What every reader of a received `query:QueryRequest` needs beside its slots:
# the `query:Query` it carries, and the one way a rule of chapter 4.6 is
# refused — naming the rule in the `detail` of the failure, which reaches the
# `EDM:ERR:0003` and the journal alike.
#
# Shared by `EvidenceRequestParser` and the families of rules it composes, and
# not copied into each: the `detail` of a refusal must be the same whichever
# object refuses. The includer provides `request`, the `query:QueryRequest`.
module QueryRequestReading
  include OotsNamespaces

  private

  def refuse(rule, key, **)
    raise UnreadableMessageError.new(I18n.t(key, **), detail: rule)
  end

  def query
    @query ||= at(request, './query:Query') ||
               raise(UnreadableMessageError, I18n.t('parsers.evidence_request.no_query'))
  end
end
