# Every page of the administration space is behind a session, and a request spec
# has no way to write one directly: it goes through the form, like a browser.
#
# `has_secure_password` keeps the plaintext it was given on the record, so the
# password the factory chose is read back here rather than repeated.
module Authentication
  def sign_in(administrator = create(:administrator))
    post admin_session_path, params: { email: administrator.email, password: administrator.password }

    # Asserted here rather than left to fail downstream: a login that stopped
    # working would otherwise show up as every guarded spec expecting a page and
    # getting the form, which names the symptom and not the cause.
    expect(response).to redirect_to(admin_root_path)

    administrator
  end
end

RSpec.configure do |config|
  config.include Authentication, type: :request
end
