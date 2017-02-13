# $Id$
# Developer: Rosario Andolina <andolinarosario@gmail.com>
# Contributor: Carmelo Pellegrino <carmelo.pellegrino@gmail.com>
pkgname=multiprocdown
pkgver=1
pkgrel=2
pkgdesc="Fasten download processes with parallelism"
arch=(any)
license=('none')
url="https://gitlab.com/tumeo-boys/multiprocdown"
depends=('gnuplot' 'awk' 'pulseaudio' 'curl' 'bash' 'grep')
makedepends=('sed')
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
  sed -e 's:/home/rosario/Scaricati/:/usr/share/mpd/:g' -i multiprocdown
}

