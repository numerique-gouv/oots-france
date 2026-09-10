# `R-EDM-REQ-C092`, and it alone: every wording a received request carries is at
# least two characters long, wherever it sits.
#
# One rule, one walk. The assertion's context lists twenty-one element names and
# names no ancestor, so it reaches the name of an agent, the description of a
# requirement, the title of an evidence type and the place of birth of the
# person alike — which is why this is written as a walk over the document and
# not as a reading hung off each of them. The readers that do visit some of
# those elements keep their own, more precise sentence: they run first, and this
# is the net under everywhere they do not go.
#
# Apart from the parser, as the four conformance modules beside it are, and for
# the reason `RequirementConformance` states.
#
# Refusals go through `refuse`, which the parser including this defines.
module WordingConformance
  include OotsNamespaces

  # The twenty-one names of the context, verbatim and in its order, each under
  # the length the test asks of it: `$text_length > 1` for nineteen of them, and
  # `> 0` for the two the disjunction names besides. One table and not a list
  # plus its exceptions — a name in the second and not in the first would be
  # dead without anything saying so.
  MINIMUM_LENGTHS = {
    'Description' => 2, 'Name' => 2, 'Title' => 2, 'Note' => 2, 'EvidenceTypeClassification' => 2,
    'FullAddress' => 2, 'LocatorDesignator' => 1, 'PostCode' => 2, 'PostCityName' => 2, 'Thoroughfare' => 2,
    'PlaceOfBirth' => 2, 'TownOfBirth' => 2, 'PhoneNumber' => 2, 'EmailAddress' => 2, 'LegalPhoneNumber' => 2,
    'LegalEmailAddress' => 2, 'nonLatin' => 2, 'ValueExpression' => 2, 'StringValue' => 1, 'AttributeName' => 2,
    'AttributeValue' => 2,
  }.freeze

  private

  # Every `sdg:*` element of the request, filtered by the table: walking the
  # document once is what the rule's context does, where twenty-one XPath
  # expressions would only say the same thing at greater length.
  #
  # `squish` is `normalize-space`, which the assertion applies before measuring:
  # ` A ` is one character to the rule, and so is a name split over two lines.
  def require_conformant_wordings
    unanswerable = unanswerable_wording_paths

    all(request, './/sdg:*').each do |wording|
      minimum = MINIMUM_LENGTHS[wording.name]
      next if minimum.nil? || unanswerable.include?(wording.path)

      value = wording.text.squish
      next if value.length >= minimum

      refuse('R-EDM-REQ-C092', wording_key(minimum), path: wording.path, value:)
    end
  end

  # Two sentences rather than one carrying a number: shorter than one character
  # is empty, and saying so is clearer than naming a length of one — where « fait
  # moins de deux caractères » is what the readers measuring an agent's name
  # already say.
  def wording_key(minimum)
    return 'parsers.evidence_request.wording_empty' if minimum == 1

    'parsers.evidence_request.wording_too_short'
  end

  # The names of the agent classified `ER`, which this walk must not refuse:
  # `R-EDM-ERR-C027` measures the requester's name in the error response exactly
  # as `C092` measures it in the request, so a refusal that travelled back would
  # be signed into a message breaking a FATAL rule of its own.
  #
  # `EvidenceRequestParser#build_requester` is what judges them, and
  # `EvidenceProvision::RejectUnanswerableRequester` is where that silence is
  # journalled — the reading being ordered so that the requester is refused
  # before anything answers. The exception is here all the same, so that
  # `validate!` called on its own cannot turn that silent refusal into a signed
  # answer.
  #
  # Told apart by their path, which is unique in the document and does not
  # depend on how the node was reached, where object identity would depend on
  # Nokogiri handing back the same instance twice.
  #
  # Read once into a local rather than memoised on the reader: every module
  # beside this one leaves the instance variables of `EvidenceRequestParser` to
  # `EvidenceRequestParser`, and a name claimed on someone else's instance is
  # the one collision that would corrupt silently.
  def unanswerable_wording_paths = all(requester_agent, './sdg:Name').map(&:path)
end
