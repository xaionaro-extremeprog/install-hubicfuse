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
	sudo apt-get install debhelper autotools-dev libcurl4-openssl-dev libxml2-dev libssl-dev libfuse-dev pkg-config libmagic-dev libjson0-dev dpkg-dev gcc tar
	PKG_NAME="$(grep '[a-z]'    hubicfuse/debian/changelog | head -1 | awk '{print $1}')"
	PKG_VERSION="$(grep '[a-z]' hubicfuse/debian/changelog | head -1 | grep -o '(.*)' | tr -d "()")"
	tar -czvf cloudfuse_0.9.orig.tar.gz hubicfuse

	pushd hubicfuse
	dpkg-buildpackage -rfakeroot
	popd

	rm -f "$PKG_NAME"_*
	mv *.deb cloudfuse.deb
}

function getDeb {
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

	echo "/tmp/install-hubicfuse/package/${PKG_CATEGORY}/cloudfuse.deb"
	return 0
}



case "$DISTR" in
	Ubuntu)
		DEB="$(getDeb "$(echo $DISTR | tr '[:upper:]' '[:lower:]')"/"$VERSION")"
		if [ "$DEB" = "" ]; then
			echo "An error occurred. Exit. Try: bash -x $0"
			exit -1
		fi
		sudo dpkg -i "$DEB"
		rm -f "$DEB"
		;;
esac

