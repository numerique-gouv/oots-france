# Every page of the administration space is behind a session, and a request spec
# has no way to write one directly: it goes through ProConnect, like a browser —
# the button, then the return, against the doubles of `ProConnectStubs`.
module Authentication
  def sign_in(email: ProConnectStubs::AGENT_EMAIL)
    return_from_pro_connect(email:)

    # Asserted here rather than left to fail downstream: a sign-in that stopped
    # working would otherwise show up as every guarded spec expecting a page and
    # getting the login page, which names the symptom and not the cause.
    expect(response).to redirect_to(admin_root_path)

    email
  end
end

RSpec.configure do |config|
  config.include Authentication, type: :request
end
