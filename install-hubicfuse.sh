#!/bin/bash -e

DISTR=$(lsb_release -i | sed -e 's/.*:\t//g')
VERSION=$(lsb_release -c | sed -e 's/.*:\t//g')

#function getDeb {
#	PKG_CATEGORY="$1"; shift
#	PKG_URL="https://raw.githubusercontent.com/xaionaro-extremeprog/install-hubicfuse/master/${PKG_CATEGORY}/cloudfuse.deb"
#	PATH_SAVEPKG="/tmp/cloudfuse.deb.$$"
#	wget "$PKG_URL" -O /tmp/cloudfuse.deb.$$
#	RC="$?"
#	if [ "$RC" -ne "0" ]; then
#		return $RC
#	fi
#	echo "$PATH_SAVEPKG"
#	return 0
#}

function buildDeb {
	git submodule update --init --recursive

	sudo apt-get install debhelper autotools-dev libcurl4-openssl-dev libxml2-dev libssl-dev libfuse-dev pkg-config libmagic-dev libjson0-dev dpkg-dev gcc tar
	PKG_NAME="$(grep '[a-z]'    hubicfuse/debian/changelog | head -1 | awk '{print $1}')"
	PKG_VERSION="$(grep '[a-z]' hubicfuse/debian/changelog | head -1 | grep -o '(.*)' | tr -d "()")"
	PKG_VERSION_UPSTREAM="$(echo "$PKG_VERSION" | awk -F '-' '{print $1}')"
	tar -czvf "${PKG_NAME}"_"${PKG_VERSION_UPSTREAM}".orig.tar.gz hubicfuse

	pushd hubicfuse
	dpkg-buildpackage -rfakeroot
	popd

	mv *.deb cloudfuse.deb
	rm -f "$PKG_NAME"_*
}

function prepareDeb {
	PKG_CATEGORY="$1"; shift

	sudo apt-get install git

	rm -rf /tmp/install-hubicfuse

	pushd /tmp
	git clone https://github.com/xaionaro-extremeprog/install-hubicfuse
	pushd install-hubicfuse
	if ! [ -f "package/${PKG_CATEGORY}/cloudfuse.deb" ]; then
		buildDeb
		RC="$?"
		if [ "$RC" -ne "0" ]; then
			return $RC
		fi
		mkdir -p package/"${PKG_CATEGORY}"
		mv cloudfuse.deb package/"${PKG_CATEGORY}"/
		git add package/"${PKG_CATEGORY}"/cloudfuse.deb
		git commit -m "added package for ${PKG_CATEGORY}" -a
		git push
	fi

	popd
	popd

	return 0
}

function installHubicFuse {
	case "$DISTR" in
		Ubuntu)
			PKG_CATEGORY="$(echo $DISTR | tr '[:upper:]' '[:lower:]')"/"$VERSION"
			prepareDeb "${PKG_CATEGORY}"
			RC="$?"
			if [ "$RC" -ne "0" ]; then
				echo "An error occurred. Exit. Try: bash -x $0"
				exit -1
			fi
			DEB="/tmp/install-hubicfuse/package/${PKG_CATEGORY}/cloudfuse.deb"

			sudo dpkg -i "$DEB"
			#rm -rf "/tmp/install-hubicfuse"
			;;
	esac
}

function setupHubicFuse {
	pushd /tmp
	if ! [ -d "/tmp/install-hubicfuse/hubicfuse" ]; then
		rm -rf "/tmp/install-hubicfuse"
		git clone https://github.com/xaionaro-extremeprog/install-hubicfuse
		pushd install-hubicfuse
		git submodule update --init --recursive
		popd
	else
		pushd "/tmp/install-hubicfuse"
		git submodule update --init --recursive
		popd
	fi
	popd

	pushd /tmp/install-hubicfuse/hubicfuse

	export client_id="${HUBIC_CLIENT_ID}"
	export client_secret="${HUBIC_CLIENT_SECRET}"
	export user_login="${HUBIC_USER_LOGIN}"
	export user_pwd="${HUBIC_USER_PASSWORD}"
	export redirect_uri="${HUBIC_REDIRECT_URI:-http://localhost/}"
	export usage="${HUBIC_USAGE:-r}"
	export getAllLinks="${HUBIC_GETALLLINKS:-r}"
	export credentials="${HUBIC_credentials:-r}"
	export activate="${HUBIC_ACTIVATE:-}"
	export links="${HUBIC_LINKS:-}"

	# see source code of "hubic_token":
	scope='account.r'
	[ "$usage" = 'r' ] && scope="${scope},usage.r"
	[ "$getAllLinks" = 'r' ] && scope="${scope},getAllLinks.r"
	[ "$credentials" = 'r' ] && scope="${scope},credentials.r"
	[ "$activate" = 'w' ] && scope="${scope},activate.w"
	l="$( printf -- '%s' "${links}" | sed 's/[^\(w\|r\|d\)]//g' )"
	[ -n "$l" ] && [ "${l}" = "${links}" ] && scope="${scope},links.${l}"

	export scope

	./hubic_token | grep -A 31415 "^#" > ~/.hubicfuse
	#sed -e 's/read -p/echo/g' hubic_token | bash

	popd
}

for var in HUBIC_CLIENT_ID HUBIC_CLIENT_SECRET HUBIC_USER_LOGIN; do
	eval "varValue=\"\$$var\""
	if [ "$varValue" = "" ]; then
		echo "Variables HUBIC_CLIENT_ID, HUBIC_CLIENT_SECRET and HUBIC_USER_LOGIN must be set before this script. Optionally you can also set HUBIC_USER_PASSWORD." >&2
		exit 1
	fi
done

installHubicFuse
setupHubicFuse

