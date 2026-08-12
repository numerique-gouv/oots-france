# What a message asks for, named by its ebMS `Action`.
#
# Three actions carry the whole exchange: a request, the answer that carries the
# evidence, and the answer that refuses. Every layer reads them — the dispatch
# table of `IncomingMessage::Process` picks a handler on them, the parsers pick
# a reader, the builders write them into the header — so they belong to the
# domain rather than to any one of those.
#
# The values are the ones the EDM defines for the RegRep binding; see the
# "messages échangés" section of `docs/oots_context.md`.
module EbmsAction
  EXECUTE_QUERY_REQUEST = 'ExecuteQueryRequest'.freeze
  EXECUTE_QUERY_RESPONSE = 'ExecuteQueryResponse'.freeze
  EXCEPTION_RESPONSE = 'ExceptionResponse'.freeze
end
