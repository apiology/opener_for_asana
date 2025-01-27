#!/bin/bash -eu

set -o pipefail

install_nvm() {
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.2/install.sh | bash
}

set_nvm_env_variables() {
  #
  # nvm doesn't seem to be -e clean:
  #
  # https://app.circleci.com/pipelines/github/apiology/cookiecutter-chrome-extension/72/workflows/789c4aac-d150-4b0c-962f-83f8d04dd288/jobs/98
  #
  set +e
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1090,SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  # shellcheck disable=SC1090,SC1091
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
  set -e
}

ensure_nvm() {
  if ! [ -f "${HOME}/.nvm/nvm.sh" ]
  then
    install_nvm
  fi
  if ! type nvm >/dev/null 2>&1
  then
    set_nvm_env_variables
  fi
}

ensure_node_versions() {
  # Looks like nvm isn't -u clean
  #
  # https://github.com/nvm-sh/nvm/issues/2420
  #
  # https://app.circleci.com/pipelines/github/apiology/cookiecutter-chrome-extension/67/workflows/ae764563-1f72-49d1-a663-a6cc6e64060a/jobs/88
  set +u
  nvm install
  set -u
}

ensure_yarn() {
  npm install -g yarn
}

ensure_npm_modules() {
  # --prefer-offline: maximize use of yarn cache for speed
  # --no-progress: progress bar creates artifacts in M-x shell
  # --non-interactive: don't interrupt CI with a prompt
  # --ignore-scripts: don't run alfred installion scripts
  yarn install --prefer-offline --no-progress --non-interactive --ignore-scripts
}

apt_upgraded=0

update_apt() {
  if [ "${apt_upgraded}" = 0 ]
  then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
    apt_upgraded=1
  fi
}

install_rbenv() {
  if [ "$(uname)" == "Darwin" ]
  then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install rbenv || true
    if ! type rbenv 2>/dev/null
    then
      # https://github.com/pyenv/pyenv-installer/blob/master/bin/pyenv-installer
      >&2 cat <<EOF
WARNING: seems you still have not added 'rbenv' to the load path.

# Load rbenv automatically by adding
# the following to ~/.bashrc:

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
EOF
    fi
  else
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  fi
}

set_rbenv_env_variables() {
  export PATH="${HOME}/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
}

install_ruby_build() {
  if [ "$(uname)" == "Darwin" ]
  then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install ruby-build || true
  else
    mkdir -p "$(rbenv root)"/plugins
    git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
  fi
}

ensure_ruby_build() {
  if ! type ruby-build >/dev/null 2>&1 && ! [ -d "${HOME}/.rbenv/plugins/ruby-build" ]
  then
    install_ruby_build
  fi
}

ensure_rbenv() {
  if ! type rbenv >/dev/null 2>&1 && ! [ -f "${HOME}/.rbenv/bin/rbenv" ]
  then
    install_rbenv
  fi

  set_rbenv_env_variables

  ensure_ruby_build
}

latest_ruby_version() {
  major_minor=${1}

  # Double check that this command doesn't error out under -e
  rbenv install --list >/dev/null 2>&1

  # not sure why, but 'rbenv install --list' below exits with error code
  # 1...after providing the same output the previous line gave when it
  # exited with error code 0.
  #
  # https://github.com/rbenv/rbenv/issues/1441
  set +e
  rbenv install --list 2>/dev/null | cat | grep "^${major_minor}."
  set -e
}

ensure_dev_library() {
  header_file_name=${1:?header file name}
  homebrew_package=${2:?homebrew package}
  apt_package=${3:-${homebrew_package}}
  if ! [ -f /usr/include/"${header_file_name}" ] && \
      ! [ -f /usr/include/x86_64-linux-gnu/"${header_file_name}" ] && \
      ! [ -f /usr/local/include/"${header_file_name}" ] && \
      ! [ -f  /usr/local/opt/"${homebrew_package}"/include/"${header_file_name}" ]
  then
    install_package "${homebrew_package}" "${apt_package}"
  fi
}

ensure_ruby_build_requirements() {
  ensure_dev_library readline/readline.h readline libreadline-dev
  ensure_dev_library zlib.h zlib zlib1g-dev
  ensure_dev_library openssl/ssl.h openssl libssl-dev
  ensure_dev_library yaml.h libyaml libyaml-dev
}

ensure_latest_ruby_build_definitions() {
  ensure_rbenv

  git -C "$(rbenv root)"/plugins/ruby-build pull
}

# You can find out which feature versions are still supported / have
# been release here: https://www.ruby-lang.org/en/downloads/
ensure_ruby_versions() {
  ensure_latest_ruby_build_definitions

  # You can find out which feature versions are still supported / have
  # been release here: https://www.ruby-lang.org/en/downloads/
  ruby_versions="$(latest_ruby_version 3.2)"

  echo "Latest Ruby versions: ${ruby_versions}"

  ensure_ruby_build_requirements

  for ver in $ruby_versions
  do
    rbenv install -s "${ver}"
    hash -r  # ensure we are seeing latest bundler etc
  done
}

ensure_bundle() {
  # Not sure why this is needed a second time, but it seems to be?
  #
  # https://app.circleci.com/pipelines/github/apiology/source_finder/21/workflows/88db659f-a4f4-4751-abc0-46f5929d8e58/jobs/107
  set_rbenv_env_variables
  bundle --version >/dev/null 2>&1 || gem install --no-document bundler
  bundler_version=$(bundle --version | cut -d ' ' -f3)
  bundler_version_major=$(cut -d. -f1 <<< "${bundler_version}")
  bundler_version_minor=$(cut -d. -f2 <<< "${bundler_version}")
  bundler_version_patch=$(cut -d. -f3 <<< "${bundler_version}")
  # Version 2.1 of bundler seems to have some issues with nokogiri:
  #
  # https://app.asana.com/0/1107901397356088/1199504270687298

  # Version <2.2.22 of bundler isn't compatible with Ruby 3.3:
  #
  # https://stackoverflow.com/questions/70800753/rails-calling-didyoumeanspell-checkers-mergeerror-name-spell-checker-h
  need_better_bundler=false
  if [ "${bundler_version_major}" -lt 2 ]
  then
    need_better_bundler=true
  elif [ "${bundler_version_major}" -eq 2 ]
  then
    if [ "${bundler_version_minor}" -lt 2 ]
    then
      need_better_bundler=true
    elif [ "${bundler_version_minor}" -eq 2 ]
    then
      if [ "${bundler_version_patch}" -lt 23 ]
      then
        need_better_bundler=true
      fi
    fi
  fi
  if [ "${need_better_bundler}" = true ]
  then
    # need to do this first before 'bundle update --bundler' will work
    make bundle_install
    bundle update --bundler
    # ensure next step installs fresh bundle
    rm -f Gemfile.lock.installed
  fi
  make bundle_install
  # https://bundler.io/v2.0/bundle_lock.html#SUPPORTING-OTHER-PLATFORMS
  #
  # "If you want your bundle to support platforms other than the one
  # you're running locally, you can run bundle lock --add-platform
  # PLATFORM to add PLATFORM to the lockfile, force bundler to
  # re-resolve and consider the new platform when picking gems, all
  # without needing to have a machine that matches PLATFORM handy to
  # install those platform-specific gems on.'
  #
  # This affects nokogiri, which will try to reinstall itself in
  # Docker builds where it's already installed if this is not run.
  for platform in x86_64-darwin-21 x86_64-linux x86_64-linux-musl
  do
    grep "${platform:?}" Gemfile.lock >/dev/null 2>&1 || bundle lock --add-platform "${platform:?}"
  done
}

set_ruby_local_version() {
  latest_ruby_version="$(cut -d' ' -f1 <<< "${ruby_versions}")"
  echo "${latest_ruby_version}" > .ruby-version
}

latest_python_version() {
  major_minor=${1}
  # https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
  pyenv install --list | grep "^  ${major_minor}." | grep -v -- -dev | tail -1 | xargs
}

install_pyenv() {
  if [ "$(uname)" == "Darwin" ]
  then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install pyenv || true
    if ! type pyenv 2>/dev/null
    then
      # https://github.com/pyenv/pyenv-installer/blob/master/bin/pyenv-installer
      >&2 cat <<EOF
WARNING: seems you still have not added 'pyenv' to the load path.

# Load pyenv automatically by adding
# the following to ~/.bashrc:

export PYENV_ROOT="${HOME}/.pyenv"
export PATH="${PYENV_ROOT}/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)"
EOF
    fi
  else
    curl https://pyenv.run | bash
  fi
}

set_pyenv_env_variables() {
  # looks like pyenv scripts aren't -u clean:
  #
  # https://app.circleci.com/pipelines/github/apiology/cookiecutter-pypackage/15/workflows/10506069-7662-46bd-b915-2992db3f795b/jobs/15
  set +u
  export PYENV_ROOT="${HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:$PATH"
  eval "$(pyenv init --path)"
  eval "$(pyenv virtualenv-init -)"
  set -u
}

ensure_pyenv() {
  if ! type pyenv >/dev/null 2>&1 && ! [ -f "${HOME}/.pyenv/bin/pyenv" ]
  then
    install_pyenv
  fi

  if ! type pyenv >/dev/null 2>&1
  then
    set_pyenv_env_variables
  fi
}

install_package() {
  homebrew_package=${1:?homebrew package}
  apt_package=${2:-${homebrew_package}}
  if [ "$(uname)" == "Darwin" ]
  then
    HOMEBREW_NO_AUTO_UPDATE=1 brew install "${homebrew_package}"
  elif type apt-get >/dev/null 2>&1
  then
    update_apt
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${apt_package}"
  else
    >&2 echo "Teach me how to install packages on this plaform"
    exit 1
  fi
}

ensure_python_build_requirements() {
  ensure_dev_library zlib.h zlib zlib1g-dev
  ensure_dev_library bzlib.h bzip2 libbz2-dev
  ensure_dev_library openssl/ssl.h openssl libssl-dev
  ensure_dev_library ffi.h libffi libffi-dev
  ensure_dev_library sqlite3.h sqlite3 libsqlite3-dev
  ensure_dev_library lzma.h xz liblzma-dev
  ensure_dev_library readline/readline.h readline libreadline-dev
}

# You can find out which feature versions are still supported / have
# been release here: https://www.python.org/downloads/
ensure_python_versions() {
  # You can find out which feature versions are still supported / have
  # been release here: https://www.python.org/downloads/
  python_versions="$(latest_python_version 3.11)"

  echo "Latest Python versions: ${python_versions}"

  ensure_python_build_requirements

  for ver in $python_versions
  do
    if [ "$(uname)" == Darwin ]
    then
      if [ -z "${HOMEBREW_OPENSSL_PREFIX:-}" ]
      then
        HOMEBREW_OPENSSL_PREFIX="$(brew --prefix openssl)"
      fi
      pyenv_install() {
        CFLAGS="-I/usr/local/opt/zlib/include -I/usr/local/opt/bzip2/include -I${HOMEBREW_OPENSSL_PREFIX}/include" LDFLAGS="-L/usr/local/opt/zlib/lib -L/usr/local/opt/bzip2/lib -L${HOMEBREW_OPENSSL_PREFIX}/lib" pyenv install --skip-existing "$@"
      }

      major_minor="$(cut -d. -f1-2 <<<"${ver}")"
      pyenv_install "${ver}"
    else
      pyenv install -s "${ver}"
    fi
  done
}

ensure_pyenv_virtualenvs() {
  latest_python_version="$(cut -d' ' -f1 <<< "${python_versions}")"
  virtualenv_name="opener-for-asana-${latest_python_version}"
  pyenv virtualenv "${latest_python_version}" "${virtualenv_name}" || true
  # You can use this for your global stuff!
  pyenv virtualenv "${latest_python_version}" mylibs || true
  # shellcheck disable=SC2086
  pyenv local "${virtualenv_name}" ${python_versions} mylibs
}

ensure_pip_and_wheel() {
  # pip 22 seems to be better at finding pandas pre-compiled wheels
  # for macOS, so let's make sure we're using at least that version
  major_pip_version=$(pip --version | cut -d' ' -f2 | cut -d '.' -f 1)
  if [[ major_pip_version -lt 21 ]]
  then
    pip install 'pip>=22'
  fi
  # wheel is helpful for being able to cache long package builds
  pip show wheel >/dev/null 2>&1 || pip install wheel
}

ensure_python_requirements() {
  make pip_install
}

ensure_shellcheck() {
  if ! type shellcheck >/dev/null 2>&1
  then
    install_package shellcheck
  fi
}


ensure_overcommit() {
  # don't run if we're in the middle of a cookiecutter child project
  # test, or otherwise don't have a Git repo to install hooks into...
  if [ -d .git ]
  then
    bundle exec overcommit --install
  else
    >&2 echo 'Not in a git repo; not installing git hooks'
  fi
}

ensure_nvm

ensure_node_versions

ensure_yarn

ensure_npm_modules

ensure_ruby_versions

set_ruby_local_version

ensure_bundle

ensure_pyenv

ensure_python_versions

ensure_pyenv_virtualenvs

ensure_pip_and_wheel

ensure_python_requirements

ensure_shellcheck

ensure_overcommit
