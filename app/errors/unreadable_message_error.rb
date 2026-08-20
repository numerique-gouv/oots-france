# A message from a foreign correspondent France will not act on: one it cannot
# read — a slot missing, a slot present but empty, an identity it cannot
# extract — or one it reads perfectly well and still refuses, for a business
# rule of chapter 4.6, for the request identifier chapter 4.4 forbids reusing,
# or for a version its ebMS header and its body do not agree on.
#
# `detail` names the rule, and travels to the `detail` attribute of the
# `rs:Exception` the correspondent receives: without it they read « invalid
# request » and nothing else. English and outside `fr.yml`, like every other
# value the TDD fix, because it is read by a foreign machine and not by a
# French screen.
#
# Flat, and not an EbmsError, on purpose: EbmsError drives the 422 we return to
# the French service provider, and a malformed foreign message is not their
# fault. This one turns into an `EDM:ERR:0003` RegRep response addressed to the
# correspondent instead.
class UnreadableMessageError < StandardError
  attr_reader :detail

  def initialize(message = nil, detail: nil)
    super(message)
    @detail = detail
  end
end
