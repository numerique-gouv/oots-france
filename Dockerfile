# The version is pinned to an exact patch, and must stay in step with
# `.ruby-version` and the matrix of `.github/workflows/tests.yml`. A floating
# `ruby:4.0` would let a cached image drift far behind continuous integration,
# and the symptom would be a local `make e2e` failing on a Ruby the workflow
# never exercises. After any bump here: `docker compose build --pull web`.
FROM ruby:4.0.6-slim

# `libpq-dev` for `pg`'s native extension, `libyaml-dev` for Psych,
# `build-essential` to compile native gems, `git` because Bundler needs it as
# soon as a gem comes from a repository.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential curl git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

# The gems install outside `/usr/src/app`, at the image's default location: the
# compose stack mounts the repository onto that directory, and gems installed
# underneath would be masked by the mount.
COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . /usr/src/app

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
