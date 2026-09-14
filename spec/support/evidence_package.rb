# A received response whose package carries a supplementary document beside its
# main one — what chapter 4.5.2 §2.6 calls « Evidence Packaging », and the one
# shape the captured messages do not hold: the answer a real gateway delivered
# carries a single document, so an annex and the association binding it have to
# be fabricated to be judged.
#
# Apart from `Fixtures`, whose `envelope_with_body` it builds on: that module
# reads the reference messages, this one shapes one of them into a case the
# rules of §2.6 have something to say about.
module EvidencePackage
  # The `id` of the object the captured response classifies `MainEvidence`, and
  # the two minted beside it below. Written out because a spec that breaks an
  # association has to name the end it is breaking.
  MAIN_EVIDENCE_ID = 'urn:uuid:ab42bdbd-5777-4c2f-ae78-7e1230f42487'.freeze
  ANNEX_ID = 'urn:uuid:5bb9b4bb-6ad4-4ff2-9bb3-b52b4e4ad3f1'.freeze
  ASSOCIATION_ID = 'urn:uuid:9a3f2b4c-4a65-4d2e-8f12-1f8a2c6de4b7'.freeze

  # The captured response with a supplementary document added to its package:
  # an annex classified as chapter 4.5.2 §2.6 asks, a repository item of its
  # own, and the association binding it to the `MainEvidence`. Conformant to
  # the twenty-five packaging rules as it stands, so that every variant a spec
  # needs is one substitution away from a message a correspondent could send.
  #
  # The two objects go in before the closing tag of the nested list, which is
  # the first one the body carries — the package's own closes last.
  def response_with_an_annex
    supplementary = "#{annex_object}#{annex_association}"

    envelope_with_body('reponseAvecPieceJointe') do |body|
      packaged = body.sub('</rim:RegistryObjectList>', "#{supplementary}</rim:RegistryObjectList>")

      block_given? ? yield(packaged) : packaged
    end
  end

  # What `R-EDM-RESP-S063` leaves an annex: an identifier and a distribution
  # naming its format. Neither the subject, nor the issuing authority, nor the
  # conformance, nor either date — those belong to the main document alone.
  def annex_object
    <<~XML
      <rim:RegistryObject xsi:type="rim:ExtrinsicObjectType" id="#{ANNEX_ID}">
        <rim:Slot name="EvidenceMetadata">
          <rim:SlotValue xsi:type="rim:AnyValueType">
            <sdg:Evidence>
              <sdg:Identifier>7d0c5a91-0b3e-4a2f-9c64-2ab0d1e8f5c7</sdg:Identifier>
              <sdg:Distribution>
                <sdg:Format>application/pdf</sdg:Format>
              </sdg:Distribution>
            </sdg:Evidence>
          </rim:SlotValue>
        </rim:Slot>
        <rim:Classification id="urn:uuid:6d1e0f7a-9c2b-4d35-8e41-0a7c3b5d9e26"
                            classificationScheme="urn:fdc:oots:classification:edm"
                            classificationNode="Annex"/>
        <rim:RepositoryItemRef xlink:href="cid:annexe@pdf.oots.fr" xlink:title="Annexe"/>
      </rim:RegistryObject>
    XML
  end

  # The association of `R-EDM-RESP-S052` and `-S056`, read forwards, and of
  # `-S059`, read backwards: from the annex to the main document, typed as the
  # classification of its source.
  def annex_association
    <<~XML
      <rim:RegistryObject xsi:type="rim:AssociationType" id="#{ASSOCIATION_ID}"
                          type="urn:oasis:names:tc:ebxml-regrep:AssociationType:Annex"
                          sourceObject="#{ANNEX_ID}" targetObject="#{MAIN_EVIDENCE_ID}"/>
    XML
  end
end

RSpec.configure { |config| config.include(EvidencePackage) }
