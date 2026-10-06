# The parties of the PMode the gateway has loaded, for the two pages of the
# console that read them. When the gateway does not list them, the page answers
# `502`, whether the gateway is down or refuses the Plugin User — unlike a directory, whose
# refusal is an answer to show: a Plugin User refused is France's own
# configuration to correct.
module ReadsPmodeParties
  extend ActiveSupport::Concern

  included do
    rescue_from GatewayError, with: :render_gateway_error
  end

  private

  # Read once per request: `create` lists the parties to test them, then again
  # to answer with their blocks.
  def pmode_parties = @pmode_parties ||= DomibusPartiesClient.new.parties

  def access_point_rows
    AccessPointRow.all(parties: pmode_parties, tests: ConnectivityTest.all,
      countries: country_names)
  end

  # What the page's controller asks for, and splices block by block.
  def render_blocks(rows) = render_fragment('admin/common_services/access_points/access_points', locals: { rows: })

  def render_gateway_error(error)
    @error = error
    render 'admin/common_services/access_points/gateway_error', status: :bad_gateway
  end
end
