TERMUX_PKG_HOMEPAGE=https://quickjs-ng.github.io/quickjs/
TERMUX_PKG_DESCRIPTION="Embeddable JavaScript engine in C (NG fork)"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="0.15.1"
TERMUX_PKG_REVISION=1
TERMUX_PKG_SRCURL="https://github.com/quickjs-ng/quickjs/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz"
TERMUX_PKG_SHA256=c4e813951b7c46845096a948e978c620b11ab4cf5fd622ca09c727ec31f42623
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_CONFLICTS="quickjs"
TERMUX_PKG_PROVIDES="quickjs"
TERMUX_PKG_REPLACES="quickjs"
# Build qjs STATICALLY (link libqjs into the executable) instead of against a shared libqjs.so.
# youtubedl-android runs qjs as a standalone binary renamed to libqjs.so; a separate shared
# libqjs.so would be a second file of the same name the renamed exe can't find at runtime
# ("CANNOT LINK EXECUTABLE: library libqjs.so not found"). Static = self-contained, no such issue.
TERMUX_PKG_EXTRA_CONFIGURE_ARGS="
-DBUILD_SHARED_LIBS=OFF
"
