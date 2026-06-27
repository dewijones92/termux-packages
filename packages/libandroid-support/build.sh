TERMUX_PKG_HOMEPAGE=https://github.com/termux/libandroid-support
TERMUX_PKG_DESCRIPTION="Library extending the Android C library (Bionic) for additional multibyte, locale and math support"
TERMUX_PKG_LICENSE="Apache-2.0, MIT"
TERMUX_PKG_VERSION=(29
                    4)
TERMUX_PKG_REVISION=2
TERMUX_PKG_LICENSE_FILE="LICENSE.txt, wcwidth-${TERMUX_PKG_VERSION[1]}/LICENSE.txt"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_SRCURL=(https://github.com/termux/libandroid-support/archive/refs/tags/v${TERMUX_PKG_VERSION[0]}.tar.gz
                   https://github.com/termux/wcwidth/archive/refs/tags/v${TERMUX_PKG_VERSION[1]}.tar.gz)
TERMUX_PKG_SHA256=(8f74ce0f9cf70ec29f548696c248cac0ba560a2d8916a0fe1cf9316d5f167a80
                   08489e00f797ffb3b71f9c1894c83e5ebe12c90a2ee0e1f9dc7c6eb29a2ff1a8)
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_ESSENTIAL=true
TERMUX_PKG_AUTO_UPDATE=false

termux_step_post_get_source() {
	cp wcwidth-${TERMUX_PKG_VERSION[1]}/wcwidth.c src/

	# API-23 backfill: libc symbols Bionic only added at API 24 (@LIBC_N). Defining them here
	# (libandroid-support is force-linked into every Termux build) lets prebuilt-for-API-24 deps
	# such as ffmpeg's libsrt/libssh/libzmq/libidn2 link and run on Android 6.0 (API 23).
	# This is the proven set from the youtubedl-android API-23 work, now in its proper home.
	cat > src/api23_compat.c <<-'CEOF'
		#if !defined(__ANDROID_API__) || __ANDROID_API__ < 24
		#include <stddef.h>
		#include <stdlib.h>

		/* getifaddrs/freeifaddrs + if_nameindex (added API 24) -- benign stubs */
		struct ifaddrs;
		int getifaddrs(struct ifaddrs **ifap) { if (ifap) *ifap = NULL; return 0; }
		void freeifaddrs(struct ifaddrs *ifa) { (void) ifa; }
		struct if_nameindex { unsigned int if_index; char *if_name; };
		struct if_nameindex *if_nameindex(void) {
			return (struct if_nameindex *) calloc(1, sizeof(struct if_nameindex));
		}
		void if_freenameindex(struct if_nameindex *p) { free(p); }

		/* IPv6 wildcard/loopback constants (added API 24). 16-byte objects (:: and ::1);
		 * byte arrays avoid <netinet/in.h>'s per-TU static declaration. */
		const unsigned char in6addr_any[16] = {0};
		const unsigned char in6addr_loopback[16] = {[15] = 1};

		/* strchrnul (added API 24) -- used by libidn2 */
		char *strchrnul(const char *s, int c) {
			while (*s && *s != (char) c) s++;
			return (char *) s;
		}
		#endif
	CEOF
}

termux_step_make() {
	local c_file

	mkdir -p objects
	for c_file in $(find src -type f -iname \*.c); do
		$CC $CPPFLAGS $CFLAGS -std=c99 -DNULL=0 -fPIC -Iinclude \
			-c $c_file -o ./objects/$(basename "$c_file").o
	done

	cd objects
	ar rcu ../libandroid-support.a *.o
	$CC $LDFLAGS -shared -o ../libandroid-support.so *.o
}

termux_step_make_install() {
	install -Dm600 libandroid-support.a $TERMUX_PREFIX/lib/libandroid-support.a
	install -Dm600 libandroid-support.so $TERMUX_PREFIX/lib/libandroid-support.so
}
