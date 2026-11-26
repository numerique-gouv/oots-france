# The gateway refused a submission with a SOAP fault, and this carries what the
# fault says in place of Faraday's status line, which names only the status and
# the address of the gateway. A `Faraday::Error` still, so that every caller already
# rescuing one takes it unchanged; the gateway's answer stays on `response`.
class SubmissionRefused < Faraday::Error; end
