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
#
# Back to the sign-in page of the line and the procedure the flow left from,
# where the other FranceConnect+ is offered; a return this browser never asked
# for has neither to go back to, and lands on the screen the line is chosen on.
module RefusesIdentification
  private

  def refuse_identification(result, version:, procedure:)
    back = version && procedure ? admin_demo_home_path(version:, procedure:) : admin_demo_root_path

    redirect_to back,
      flash: { alert: :"interactors.failures.#{result.error[:key]}", details: result.error[:errors] }
  end
end
