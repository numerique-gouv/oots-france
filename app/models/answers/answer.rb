module Answers
  # What the three answers France returns share — a refusal, the document, or
  # the announcement of a date.
  #
  # One type each, so that no object can carry two answers at once: the
  # constructors are the only thing that could hold that invariant, and an
  # invariant held by a constructor alone is one that gives way. Each declares
  # the one member it is about, and refuses it empty — a served answer with no
  # document, a deferral with no date and a refusal with no exception are
  # exactly the states these types exist to rule out.
  #
  # Including this module is what declares membership: a fourth answer that
  # forgot `record` or `settle` would otherwise be found by a `NoMethodError`,
  # the first time that path ran.
  #
  # Each carries the envelope's *builder* rather than its render — `SubmitAnswer`
  # renders it and `JournalAnswer` reads the first MIME part back from it, and
  # rendering twice would mint a second message identifier — and answers the two
  # questions the end of the chain puts to it: which line of the log to write,
  # and how the exchange closes.
  module Answer
    # Only a refusal names one, and `answer_not_sent` records it whichever
    # answer the gateway would not take. Overridden by the member `Refusal`
    # declares, an accessor of the class winning over an included module.
    def exception = nil

    private

    def refuse_missing(value, name)
      raise ArgumentError, "#{self.class.name} sans #{name}" if value.nil?
    end
  end
end
