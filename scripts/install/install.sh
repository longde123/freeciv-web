#!/bin/bash

#   Copyright (C) 2018  The Freeciv-web project
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e
unset CDPATH

FCW_INSTALL_MODE=DFLT
FCW_INSTALL_VND=
FCW_INSTALL_REL=
SHOW_LIST=0
basedir=

show_help () {
  cat << EOF
${0##*/} [options]
Installs a freeciv-web server.

 -d,--dir=BASEDIR       Tells the script where the source root is.
 -h,--help              Show this message and exit.
 -l,--list              Show currently supported systems and exit.
 -m,--mode=MODE         Where MODE is one of:
                          TEST  to choose some defaults and install test infra
                          DFLT  to expect user configuration for a real server
 -s,--system VND REL    Vendor and release to use for the install script,
                        instead of autodetecting.

Send your pull requests, bug reports and feature requests to
https://github.com/freeciv/freeciv-web
EOF
}

while :; do
  case $1 in
    -h|--help)
      show_help
      exit
      ;;
    -d|--dir)
      if [ -n "$2" ]; then
        basedir=$2
        shift
      else
        echo >&2 "The --dir option requires the installation basedir as a parameter."
        exit 2
      fi
      ;;
    --dir=?*)
      basedir=${1#*=}
      ;;
    -l|--list)
      SHOW_LIST=1
      ;;
    -m|--mode)
      if [ -n "$2" ]; then
        FCW_INSTALL_MODE=$2
        shift
      else
        echo >&2 "The --mode option requires the install mode as a parameter."
        exit 2
      fi
      ;;
    --mode=?*)
      FCW_INSTALL_MODE=${1#*=}
      ;;
    -s|--system)
      if [ -n "$3" ]; then
        FCW_INSTALL_VND=$2
        FCW_INSTALL_REL=$3
        shift 2
      else
        echo >&2 "The --system option requires both a system and a release as parameters."
        exit 2
      fi
      ;;
    ?*)
      echo >&2 "Unexpected parameter: $1"
      exit 2
      ;;
    *)
      break
  esac
  shift
done

case $FCW_INSTALL_MODE in
  DFLT) ;;
  TEST) ;;
  *)
    echo >&2 "Unknown install mode: ${FCW_INSTALL_MODE}"
    exit 2
esac

if [ -z "${basedir}" ]; then
  basedir=${BASH_SOURCE%/*}
  if [ -z "${basedir}" ]; then
    echo >&2 "This script expects to find some companions, but it seems it's being executed from a pipe."
    echo >&2 "You can tell it where to look for them with the --dir option."
    exit 2
  fi
  basedir="${basedir}"/../..
fi

if [ "${basedir:0:1}" = - ]; then
  basedir=./"${basedir}"
fi

if [ ! -f "${basedir}"/scripts/install/systems ]; then
  echo >&2 "This script expects to find some companions, but they don't seem to be there:"
  if [ "${basedir:0:1}" = / ]; then
    echo >&2 "${basedir}"
  else
    echo >&2 $(pwd)/"${basedir}"
  fi
  echo >&2 "You can tell it where to look for them with the --dir option."
  exit 2
fi

cd "${basedir}" > /dev/null
basedir=$(pwd)

if [ "${SHOW_LIST}" = 1 ]; then
  echo "List of supported systems:"
  while IFS=$'\t' read -r v r s; do
    if [ -n "$v" ] && [ "${v:0:1}" != '#' ] && [ -n "$r" ] && [ -n "$s" ]; then
      echo -E "${v}"$'\t'"${r}"
    fi
  done < "${basedir}"/scripts/install/systems
  exit
fi

exec > >(tee "${basedir}/install.log")
exec 2>&1

echo "================================="
echo "Running Freeciv-web setup script."
echo "================================="
echo

uname -a
echo "basedir: ${basedir}"
lsb_release -a || true
if [ -z "${FCW_INSTALL_VND}" ]; then
  FCW_INSTALL_VND=$(lsb_release -is)
else
  echo "User provided vendor: ${FCW_INSTALL_VND}"
fi
if [ -z "${FCW_INSTALL_REL}" ]; then
  FCW_INSTALL_REL=$(lsb_release -cs)
else
  echo "User provided release: ${FCW_INSTALL_REL}"
fi
echo

if [ $(id -u) = 0 ]; then
  echo >&2 "Please don't run this script as root."
  echo >&2 "If you think you know what you are doing, remove this check and try again."
  exit 3
fi

if [ ! -f "${basedir}"/scripts/configuration.sh ]; then
  if [ "${FCW_INSTALL_MODE}" = TEST ]; then
    cp "${basedir}"/scripts/configuration.sh{.dist,}
    echo "Default config parameters used"
  else
    echo >&2 "Please copy scripts/configuration.sh.dist to scripts/configuration.sh and"
    echo >&2 "edit its content to suit your needs."
    exit 4
  fi
fi

if [ ! -f "${basedir}"/freeciv-web/src/main/webapp/WEB-INF/config.properties ]; then
  if [ "${FCW_INSTALL_MODE}" = TEST ]; then
    cp "${basedir}"/freeciv-web/src/main/webapp/WEB-INF/config.properties{.dist,}
    echo "Default config.properties used"
  else
    echo >&2 "Please copy freeciv-web/src/main/webapp/WEB-INF/config.properties.dist to"
    echo >&2 "freeciv-web/src/main/webapp/WEB-INF/config.properties and edit its content to"
    echo >&2 "suit your needs."
    exit 4
  fi
fi

FCW_INSTALL_SCRIPT=
while IFS=$'\t' read -r v r s; do
  if [ -n "$v" ] && [ "${v:0:1}" != '#' ] && [ "${v}" = "${FCW_INSTALL_VND}" ] \
  && [ -n "$r" ] && [ "${r}" = "${FCW_INSTALL_REL}" ] \
  && [ -n "$s" ]; then
    FCW_INSTALL_SCRIPT=$s
    break
  fi
done < "${basedir}"/scripts/install/systems

if [ -z "${FCW_INSTALL_SCRIPT}" ]; then
  echo >&2 "Don't know how to install freeciv-web in this system."
  echo >&2 "You may try passing the --system option with a supported similar one."
  exit 5
fi

. "${basedir}/scripts/configuration.sh"
. "${basedir}/scripts/install/ext-install.sh"
. "${basedir}/scripts/install/${FCW_INSTALL_SCRIPT}"

if which service > /dev/null; then
  svcman=default
  start_svc () {
    sudo service "$1" start
  }
  stop_svc () {
    sudo service "$1" stop
  }
else
  svcman=systemd
  if which pkexec > /dev/null; then
    ACCESS_MANAGER=
  else
    ACCESS_MANAGER=sudo
  fi
  start_svc () {
    ${ACCESS_MANAGER} systemctl start "$1".service
  }
  stop_svc () {
    ${ACCESS_MANAGER} systemctl stop "$1".service
  }
fi

for action in start stop; do
  if [ ! -f "${basedir}/scripts/dependency-services-${action}.sh" ]; then
    ln -s "install/dependency-services-${svcman}-${action}.sh" "${basedir}/scripts/dependency-services-${action}.sh" || cp "${basedir}/scripts/install/dependency-services-${svcman}-${action}.sh" "${basedir}/scripts/dependency-services-${action}.sh"
  fi
done

echo "==== Filling configuration templates ===="
"${basedir}/scripts/install/gen-from-templates.sh"

echo "==== Setting up DB ===="
pidof mysqld > /dev/null || start_svc mysql
if [ -z "${DB_ROOT_PASSWORD}" ]; then
  echo "Will need the DB root password twice"
fi
sudo mysqladmin -u root -p"${DB_ROOT_PASSWORD}" create "${DB_NAME}"
sudo mysql -u root -p"${DB_ROOT_PASSWORD}" << EOF
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}',
            '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD}',
            '${DB_USER}'@'::1'       IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'localhost',
                             '${DB_USER}'@'127.0.0.1',
                             '${DB_USER}'@'::1';
EOF

echo "==== Building freeciv ===="
echo "Please be patient"
cd "${basedir}"/freeciv && ./prepare_freeciv.sh
cd freeciv && make install

echo "==== Building freeciv-web ===="
cd "${basedir}"/scripts/freeciv-img-extract/ && ./setup_links.sh && ./sync.sh
cd /var/lib/tomcat8 && sudo rm -rf webapps/ROOT; sudo mkdir -p webapps/data/{savegames/pbem,scorelogs,ranklogs} && sudo chmod -R 777 webapps logs && sudo setfacl -d -m g::rwx webapps && sudo chown -R www-data:www-data webapps/

if [ ! -f "${basedir}"/publite2/settings.ini ]; then
  cp "${basedir}"/publite2/settings.ini{.dist,}
fi

cd "${basedir}"/scripts && ./sync-js-hand.sh
cd "${basedir}"/freeciv-web && ./build.sh

echo "==== Setting up nginx ===="
stop_svc nginx
sudo rm /etc/nginx/sites-enabled/default
sudo cp "${basedir}"/publite2/nginx.conf /etc/nginx/nginx.conf
if [ "${FCW_INSTALL_MODE}" = TEST ] && [ ! -f /etc/nginx/ssl/freeciv-web.crt ]; then
  sudo mkdir -p /etc/nginx/ssl/private
  sudo chmod 700 /etc/nginx/ssl/private
  openssl req -x509 -newkey rsa:2048 -keyout freeciv-web.key -out freeciv-web.crt -days 3650 -nodes -subj '/CN=localhost'
  sudo mv freeciv-web.crt /etc/nginx/ssl/
  sudo mv freeciv-web.key /etc/nginx/ssl/private/
fi

echo
echo Freeciv-web installed!
if [ ${#ext_installed[*]} -ne 0 ]; then
  echo "Some components have been installed outside the package managers:"
  for m in "${ext_installed[@]}"; do
    echo "  ${m}"
  done
fi

cat << EOF

You may want to personalize some things before starting it:
- Replace the scripts to start/stop dependency services in scripts.
- Configure the game server in publite2/settings.ini, and update/create
  pubscript_*.serv to suit your needs.
- Set the mail account data for pbem games in pbem/settings.ini, and the
  templates for the messages in pbem/email_template* (at least the URL).
- Users for tomcat-admin web interface.
- Point /etc/nginx/nginx.conf to your SSL certificate and key.

Then run scripts/start-freeciv-web.sh and enjoy!
EOF

