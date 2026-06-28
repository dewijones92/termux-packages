TERMUX_PKG_HOMEPAGE=https://aria2.github.io
TERMUX_PKG_DESCRIPTION="Download utility supporting HTTP/HTTPS, FTP, BitTorrent and Metalink"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="1.37.0"
TERMUX_PKG_REVISION=6
TERMUX_PKG_SRCURL="https://github.com/aria2/aria2/releases/download/release-${TERMUX_PKG_VERSION}/aria2-${TERMUX_PKG_VERSION}.tar.xz"
TERMUX_PKG_SHA256=60a420ad7085eb616cb6e2bdf0a7206d68ff3d37fb5a956dc44242eb2f79b66b
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_UPDATE_VERSION_REGEXP="\d+\.\d+\.\d+"
TERMUX_PKG_UPDATE_TAG_TYPE="newest-tag" # As of 2022-05-11T00:08:00 no github releases are available.
# c-ares dropped for API 23: it's a prebuilt-for-API-24 lib that references getifaddrs@LIBC_N
# (unavailable on API 23). aria2 falls back to synchronous name resolution without it.
# libxml2 dropped: only used for Metalink (yt-dlp never uses it), and libxml2 drags in ICU
# (libicudata.so ~33MB of Unicode data) — dead weight in the youtubedl-android bundle.
TERMUX_PKG_DEPENDS="libc++, openssl, zlib"
# sqlite3 is only used for loading cookies from firefox or chrome:
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
--with-openssl
--without-gnutls
--without-libuv
--without-sqlite3
--without-libssh2
--without-libcares
--without-libxml2
--without-libexpat
ac_cv_func_basename=yes
ac_cv_func_getaddrinfo=yes
ac_cv_func_gettimeofday=yes
ac_cv_func_sleep=yes
ac_cv_func_usleep=yes
ac_cv_search_getaddrinfo=no
ac_cv_func_getifaddrs=no
ac_cv_func_freeifaddrs=no
"

termux_step_pre_configure() {
	if [ "$TERMUX_ARCH" = "arm" ]; then
		CXXFLAGS="${CFLAGS/-Oz/-Os}"
	fi
}
