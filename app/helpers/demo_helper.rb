module DemoHelper
  # The preview address a correspondent named, offered as a link only where
  # chapter 4.9 §4 allows one to be followed — « specify secure HTTP
  # ("https://") as transport. The use of "http://" URIs is not allowed. » — and
  # read as the plain text it already was otherwise.
  #
  # Not `ApplicationHelper#external_link`, which admits `http`: the console
  # archives what a correspondent wrote, where this page would be sending a user
  # there.
  def demo_preview_address(wording)
    return wording.preview_location unless wording.secure_preview?

    link_to wording.preview_location, wording.preview_location,
      class: 'fr-link', target: '_blank', rel: 'noopener'
  end
end
