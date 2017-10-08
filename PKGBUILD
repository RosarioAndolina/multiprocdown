# $Id$
# Developer: Rosario Andolina <andolinarosario@gmail.com>
# Contributor: Carmelo Pellegrino <carmelo.pellegrino@gmail.com>
pkgname=multiprocdown
pkgver=2
pkgrel=1
pkgdesc="Fasten download processes with parallelism"
arch=(any)
license=('none')
url="https://gitlab.com/tumeo-boys/multiprocdown"
depends=('pulseaudio' 'curl')
optdepends=('mplayer: alternative audio support' 'vlc: alternative audio support' 'gnuplot: for grafical output'
			'tor: download anonimously')
provides=('multiprocdown')
replaces=()
conflicts=()

package() {
  cd "${srcdir}"
  mkdir -p ${pkgdir}/usr/bin/
  mkdir -p ${pkgdir}/usr/share/mpd/
  install -m 644 ../demonstrative.ogg ../breaking-some-glass.ogg ${pkgdir}/usr/share/mpd/
  install -m 755 ../scarica2.sh ${pkgdir}/usr/bin/multiprocdown
  cd ${pkgdir}/usr/bin/
  ln -s multiprocdown mpd
  sed -e 's:/home/rosario/programmi/bash/scarica/:/usr/share/mpd/:g' -i multiprocdown
}

