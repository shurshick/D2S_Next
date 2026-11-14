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
 arm64) expected=dcbb9865a87f0ac9becb6b5c9b8aad7964b1d4a6704b3d6d1b4e0499500f6cfe;;
 armv7) expected=3990157afccbe029ed7cf8cb5d3780b5adec5244165308e0bc999c246da618c2;;
 mipsel) expected=e26db82aeca61d5fdadb5016eb3ae714e81440d24fb9213fafbbb0b2697948fa;;
 mips) expected=5645a631e6e44f99f01f788b1e4c42e3626cb5e318b34b1b1876aad9b1e5e601;;
 x86_64) expected=ed14b7abac780a56ded44f61cb0a799b03d0e5fb47345e888bb3612fa9a19857;;
esac
version=0.1.0-rc4.12
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
