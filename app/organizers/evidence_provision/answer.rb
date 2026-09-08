module EvidenceProvision
  # Answers a request another member state addressed to France.
  #
  # What goes back depends on the procedure asked for: `00` and `T1` are served
  # with a document, `R1` is answered with the deferral of chapter 4.5.2, and
  # every other procedure is refused with `EDM:ERR:0004` — the expected
  # behaviour as long as no real provider is connected.
  #
  # A chain, as the other two flows already are. The first step is deliberately
  # apart from the rest: what it refuses cannot be answered at all, where
  # everything `ChooseAnswer` turns away becomes an exception response that does
  # go back.
  class Answer < ApplicationOrganizer
    organize RejectMalformedIdentifiers, ChooseAnswer, SubmitAnswer, JournalAnswer
  end
end
