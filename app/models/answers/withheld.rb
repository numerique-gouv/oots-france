module Answers
  # Chapter 4.9 §3: « the Data Service shall not provide an evidence response
  # […] before the user has decided ». Nothing goes out, nothing is recorded,
  # and the exchange stays open until the decision answers it.
  Withheld = Data.define do
    include Answer

    def withheld? = true

    def envelope = nil

    def record(*, **) = nil

    def settle(_exchange) = nil
  end
end
