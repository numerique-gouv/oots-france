# The zone of a card on the documents page where the documents are asked for:
# one `DemoRequestComponent` per evidence type of the combination the card
# names, each following its own request — chapter 4.4 §4.2.2 has « different
# basic flows … executed sequentially and/or in parallel », and a combination is
# satisfied only once each of its types is (chapter 3.2.2 §2.3).
#
# The types of a combination are asked for one after the other, in its order:
# the blocks after the first whose document is not in hand are `queued`, which
# `ReadsDemoRequest#demo_request_zone` decides.
#
# One zone per requirement the page can name, on its own address:
# `requirement_uuid` is what says which card it answers for. A page carries
# several, and none of them knows anything of the others.
class DemoRequestZoneComponent < ViewComponent::Base
  # What a block says of its type: its UUID, which the addresses carry, and its
  # name in the language the directory published it in.
  Type = Data.define(:uuid, :name, :language)

  def initialize(requirement_uuid:, blocks:)
    @requirement_uuid = requirement_uuid
    @blocks = blocks
    super()
  end

  attr_reader :blocks

  # Every document of a combination of several types in hand: chapter 3.2.2
  # §2.3 has the list « satisfied, if and only if, for all included Evidence
  # Types in this List, corresponding conformant Evidence(s) are provided ».
  def complete? = blocks.many? && blocks.all?(&:delivered?)

  # Asked again while any block waits: a settled zone carries no polling at all,
  # which is what stops the asking.
  def polling? = blocks.any?(&:polling?)

  # What the zone says, block by block: the controller compares it with what is
  # on screen, and a waiting that goes on is not replaced. A queued block
  # counts, so that the document before it arriving is a change.
  def outcome = blocks.map(&:state).join(' ')
end
