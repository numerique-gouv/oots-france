module EvidenceRequest
  # Opens the token the service provider sent, which is the only thing that says
  # whom the evidence is about.
  class DecryptBeneficiary < ApplicationInteractor
    def call
      context.beneficiary = BeneficiaryToken.new(context.requester).beneficiary(context.encrypted_beneficiary)
    rescue InvalidTokenError => e
      fail_with_error(:invalid_token, errors: [e.message])
    end
  end
end
