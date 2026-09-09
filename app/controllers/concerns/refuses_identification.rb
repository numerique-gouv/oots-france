# How the two doors of the European flow turn down a refused identification.
#
# Two doors and one wording: the button of the demonstration's home page, and
# the address FranceConnect+ returns the user to. They have no common ancestor
# but `ApplicationController` — one is guarded by the operator's session, the
# other answers to a caller holding none — and both must send the operator back
# to the start of the procedure carrying the same reason.
#
# The alert is a key, which `layouts/_messages` translates; the details are the
# reason the step wrote, which no key could hold in advance.
module RefusesIdentification
  private

  def refuse_identification(result)
    redirect_to admin_demo_root_path,
      flash: { alert: :"interactors.failures.#{result.error[:key]}", details: result.error[:errors] }
  end
end
