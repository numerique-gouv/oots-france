# The exchanges as the *server* settled them, read where `ServerAuditEvent`
# reads the log, for the same reason: the scenarios and the server do not share
# a database.
class ServerExchange < Exchange
  establish_connection(
    ActiveRecord::Base.configurations.configs_for(env_name: 'development', name: 'primary'),
  )
end
