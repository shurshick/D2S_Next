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
 arm64) expected=6494c907ccd7cde8cde2df4ada22e4b7c54cf48c09530499b829f770735b6648;;
 armv7) expected=d1041211041c643f36aba3b33a9594c2d175b1db07e1e32cc4d70fdda0a47a9a;;
 mipsel) expected=bcebfe46498becc1013f4e49d77a6ec41e3b7b4ba43f7f9af1f3747a7b461eb0;;
 mips) expected=fcb055d67e309460049e3c872d17a3d55095b799dd80293087f004f10b59a66b;;
 x86_64) expected=dc718bb22c1861866a2c95bf75c488da0b05266af040c59e5594b9292852aef1;;
esac
version=0.1.0-rc4.11
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
