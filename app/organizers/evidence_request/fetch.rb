module EvidenceRequest
  # Asks another member state for a piece of evidence, on behalf of a French
  # service provider.
  #
  # This is what the application did in a single chain of eighty lines, which
  # resolved the directories, decrypted, sent, *waited*, redirected and caught.
  # The waiting is gone: the answer arrives through a gateway notification, and
  # the conversation is what ties the two together.
  class Fetch < ApplicationOrganizer
    organize ResolveRequester,
      DecryptBeneficiary,
      ResolveEvidenceType,
      ResolveProvider,
      ResolveAccessPoint,
      OpenConversation,
      SendToGateway
  end
end
