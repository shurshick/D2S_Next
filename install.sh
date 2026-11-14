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
 arm64) expected=9122871f7d7c6b1d5a72e6e3bd013d473c63df0ece8e6fa6db14dca759f6d2d1;;
 armv7) expected=1324ef1062ad994de6f0e29794021d15bafea68fb393e77d91c996a64d89f301;;
 mipsel) expected=674130a3c4535a7c1ec9c3840e33b94fd9efb2bab6a6a86e03781012cf2017e9;;
 mips) expected=0b047dc266de94fcc00f820caa7f3b2501e90c58be5bc34ff7f6f716fc9bbbac;;
 x86_64) expected=16a4ac184923d48de996bdf1a760cc89fc5294d03d8f8dd5d919b0d75ae8779b;;
esac
version=0.1.0-rc4.14
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
