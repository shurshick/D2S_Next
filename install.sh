#!/bin/sh
set -eu
PATH=/opt/sbin:/opt/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
[ "$(id -u)" = 0 ] || { echo 'Запустите от root'; exit 1; }
if [ "${1:-}" = --uninstall ]; then
 [ "$#" = 1 ] || { echo 'Использование: sh install.sh --uninstall';exit 2; }
 if [ ! -e /opt/d2s-next ] && [ ! -L /opt/d2s-next ]; then echo 'D2S Next не установлен';exit 0;fi
 [ ! -L /opt/d2s-next ] || { echo 'Каталог продукта не должен быть ссылкой';exit 1; }
 manager=/opt/d2s-next/current/libexec/manage.sh
 resolved=$(readlink -f "$manager") || { echo 'Штатный менеджер удаления не найден';exit 1; }
 case "$resolved" in /opt/d2s-next/releases/*/libexec/manage.sh) ;; *) echo 'Недопустимый путь менеджера; удаление отменено';exit 1;; esac
 [ -f "$manager" ] || { echo 'Штатный менеджер удаления не найден';exit 1; }
 echo 'Полное удаление D2S Next: настройки, решения, журналы и MTProto-секрет будут удалены.'
 exec /bin/sh "$manager" uninstall
fi
mode=install
if [ "${1:-}" = --update ]; then mode=update;shift; [ -e /opt/d2s-next/current ] || { echo 'D2S Next не установлен';exit 1; };fi
for tool in curl sha256sum tar awk mktemp ip iptables ipset; do command -v "$tool" >/dev/null || { echo "Не найдена команда: $tool. Установите зависимости из README."; exit 1; }; done
case "$(uname -m)" in
 aarch64|arm64) arch=arm64;;
 armv7l|armv7*) arch=armv7;;
 x86_64) arch=x86_64;;
 mips|mipsel|mipsle)
 endian=$(dd if=/bin/sh bs=1 skip=5 count=1 2>/dev/null | od -An -tu1 | tr -d ' \n')
 case "$endian" in 1) arch=mipsel;; 2) arch=mips;; *) echo 'Неизвестный порядок байтов MIPS';exit 1;; esac;;
 *) echo 'Архитектура не поддерживается';exit 1;;
esac
case "$arch" in
 arm64) expected=a512b2af2f45e3706a4b4fbb0a3d1b597516667e50a87af06706ce446b5895ab;;
 armv7) expected=9720c1440afbbc4b635fe8c116cd372a59bab9c3d15102a1081894cec9bc2789;;
 mipsel) expected=f17bce5f5d42d0a9b769075358288b5438b43beb27498fc5d90fa9f9695b1140;;
 mips) expected=7cbf23cbd3d4f5e2215d9a64e1c30007a607f18c872e7c89fa961d63586c4680;;
 x86_64) expected=ae06a2d35151b9b76ad6998ebffeb46c830afc7fba8872167fac254bfceb9317;;
esac
version=0.1.0-rc4.16
if [ -r /opt/d2s-next/current/VERSION ] && [ "$(cat /opt/d2s-next/current/VERSION)" = "$version" ]; then echo "Уже установлена $version";exit 0;fi
tmp=$(mktemp -d /tmp/d2sn-online.XXXXXX)
trap 'rm -rf -- "$tmp"' 0
trap 'exit 1' 1 2 15
archive=$tmp/package.tar.gz
url=https://github.com/shurshick/D2S_Next/releases/download/$version/d2s-next-$arch.tar.gz
curl --fail --location --proto '=https' --tlsv1.2 --connect-timeout 15 --max-time 300 "$url" -o "$archive"
actual=$(sha256sum "$archive" | awk '{print $1}')
[ "$actual" = "$expected" ] || { echo 'Ошибка SHA-256; установка отменена';exit 1; }
mkdir "$tmp/verified"
tar -xzf "$archive" -C "$tmp/verified"
(cd "$tmp/verified" && sha256sum -c SHA256SUMS)
[ "$(cat "$tmp/verified/VERSION")" = "$version" ]
[ "$(cat "$tmp/verified/ARCH")" = "$arch" ]
if [ -e /opt/d2s-next/current ]; then
 /opt/d2s-next/current/libexec/manage.sh update "$archive"
else
 sh "$tmp/verified/install.sh" "$archive" "$@"
fi
