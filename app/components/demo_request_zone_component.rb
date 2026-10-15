# The zone of a card on the documents page where the documents are asked for:
# one `DemoRequestComponent` per evidence type of the combination the card
# names, each following its own request — chapter 4.4 §4.2.2 has « different
# basic flows … executed sequentially and/or in parallel », and a combination is
# satisfied only once each of its types is (chapter 3.2.4 §4.3.2).
#
# While none of its types has been asked for, a combination of several types
# offers one button that asks for them all. Once that button has been clicked —
# `requested`, which outlives a click the contract refused, since none left a
# request behind — the blocks stand, each with its own button.
#
# One zone per requirement the page can name, on its own address:
# `requirement_uuid` is what says which card it answers for. A page carries
# several, and none of them knows anything of the others.
class DemoRequestZoneComponent < ViewComponent::Base
  # What a block says of its type: its UUID, which the addresses carry, and its
  # name in the language the directory published it in.
  Type = Data.define(:uuid, :name, :language)

  def initialize(requirement_uuid:, blocks:, requested: false)
    @requirement_uuid = requirement_uuid
    @blocks = blocks
    @requested = requested
    super()
  end

  attr_reader :blocks

  def combined? = blocks.many? && !@requested && blocks.none?(&:asked?)

  # The address the combined button posts to, naming no type, and the one the
  # browser re-asks while any block waits — `RequestsController` answering both
  # with the whole zone.
  def button_path = helpers.admin_demo_demande_path(exigence: @requirement_uuid)

  # Asked again while any block waits: a settled zone carries no polling at all,
  # which is what stops the asking.
  def polling? = blocks.any?(&:polling?)

  # What the zone says, block by block: the controller compares it with what is
  # on screen, and a waiting that goes on is not replaced.
  def outcome = combined? ? 'idle' : blocks.map(&:state).join(' ')
end
