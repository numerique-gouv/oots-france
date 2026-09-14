# What a sighted reader sees of a rendered node.
#
# Two marks of the console write their meaning off screen, a colour and an icon
# saying nothing on their own (RGAA 3.1): that sentence is part of the page and
# not of the value it marks, so an assertion on what a page shows has to drop
# it.
module RenderedText
  def seen(node)
    without_hidden = node.dup
    without_hidden.css('.fr-sr-only').remove

    without_hidden.text.squish
  end
end
