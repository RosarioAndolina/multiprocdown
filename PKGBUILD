# $Id$
# Developer: Rosario Andolina <andolinarosario@gmail.com>
# Contributor: Carmelo Pellegrino <carmelo.pellegrino@gmail.com>
pkgname=multiprocdown
pkgver=2.1
pkgrel=1
pkgdesc="Fasten download processes with parallelism"
arch=(any)
license=('GPL')
url="https://gitlab.com/tumeo-boys/multiprocdown"
depends=('curl' 'gawk')
optdepends=('pulseaudio: for audio support' 'mplayer: alternative audio support' 'vlc: alternative audio support'
			'gnuplot: for grafical output' 'tor: download anonimously')
provides=('multiprocdown')
replaces=()
conflicts=()

package() {
  cd ..
  cmake -DCMAKE_INSTALL_PREFIX="${pkgdir}/usr"
  make && make install
}

