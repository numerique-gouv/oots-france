module EvidenceRequest
  # The portal confirming a preview a correspondent asked for: the second
  # request of chapter 4.9 §2 step 12 leaves, while the user visits the
  # correspondent's preview space. The subject comes from the token the portal
  # gives again, everything else from what the first request was built from —
  # the exchange keeps nothing personal between the two.
  class ConfirmPreview < ApplicationOrganizer
    organize ResolveRequester,
      DecryptBeneficiary,
      RecallFirstRequest,
      ConfirmExchange,
      SendToGateway
  end
end
