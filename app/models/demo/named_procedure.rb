module Demo
  # What the documents page stands under, kept for the clicks made on it.
  #
  # Apart from `Demo::NamedEvidence` and not folded into it: the title belongs to
  # no requirement, it stands once at the top of the page, and repeating it under
  # each card would swell a session the cookie store bounds at four kibibytes.
  #
  # Nothing is required of it. Requirement 27 of chapter 1 §2 makes the evidence
  # type and the provider a condition of the request and says nothing of the
  # procedure's own title, which no directory owes anyone: a procedure nobody has
  # named is still one a user may ask under, and the request then files no name.
  class NamedProcedure
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :procedure_name, :string
    attribute :procedure_language, :string

    # Read like `Demo::NamedEvidence`, and for the same reasons: a session
    # written under an earlier shape names nothing, which is a state this one is
    # allowed to be in.
    def self.from_session(stored)
      new(stored.to_h.symbolize_keys)
    rescue ActiveModel::UnknownAttributeError
      new
    end

    def to_session = attributes.compact
  end
end
