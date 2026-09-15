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

# The scenarios tagged `@javascript` drive a real browser, and they belong to
# the Cucumber profile everyone plays: the browser has therefore to be reachable
# from inside this container, one installed on a workstation settling nothing for
# a fresh clone. `docs/test_e2e.md` situates them, the README names the command.
#
# Its own layer, and after `bundle install`: the gems stay cached, so a rebuild
# adds this layer instead of fetching the whole bundle again — and what a browser
# needs is another reason than what a native gem needs to compile.
#
# `fonts-liberation` because it is the only font the image would otherwise
# carry none of: `chromium` depends on `libfontconfig1` and on no font package
# at all. Capybara reads what a page shows through `innerText`, which is laid
# out, so the browser is never asked to lay text out with nothing to lay it out
# with.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y chromium fonts-liberation && \
    rm -rf /var/lib/apt/lists/*

COPY . /usr/src/app

# Rails' own default, and what this image serves when nothing overrides it.
# `docker-compose.yml` does override it: the port `web` listens on is
# `PORT_OOTS_FRANCE`, so that one address serves the host's browser and the
# container network alike.
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
