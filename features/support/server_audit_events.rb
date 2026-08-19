# The exchange log as the *server* wrote it.
#
# The scenarios run in the test environment and the server in development, so
# they do not share a database — which is why every other assertion here reads
# through the application. The log is deliberately exposed by no route, so this
# is the one thing that has to be read from the database directly, and it is the
# server's that has to be read.
class ServerAuditEvent < AuditEvent
  establish_connection(
    ActiveRecord::Base.configurations.configs_for(env_name: 'development', name: 'primary'),
  )
end
