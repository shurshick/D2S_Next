#!/bin/sh
set -eu
PATH=/opt/sbin:/opt/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
[ "$(id -u)" = 0 ] || { echo 'Запустите от root'; exit 1; }
for tool in curl sha256sum tar awk mktemp ip iptables ipset; do command -v "$tool" >/dev/null || { echo "Не найдена команда: $tool. Установите зависимости из README."; exit 1; }; done
case "$(uname -m)" in
 aarch64|arm64) arch=arm64;;
 armv7l|armv7*) arch=armv7;;
 x86_64) arch=x86_64;;
 mips|mipsel|mipsle)
 endian=$(dd if=/bin/sh bs=1 skip=5 count=1 2>/dev/null | od -An -tu1 | tr -d ' \n')
 [ "$endian" = 1 ] || { echo 'Поддерживается только MIPS little-endian'; exit 1; };arch=mipsel;;
 *) echo 'Архитектура не поддерживается';exit 1;;
esac
case "$arch" in
 arm64) expected=29a824b9eef090efa465b83a3a3e92bd88a0597baf0f524d6284989ed32b1405;;
 armv7) expected=4cfd409fab77f4b7ec48dc3f148e421b22c2b4217e7df4aee74c37e5f269e710;;
 mipsel) expected=b9a7422c16ed1c819b63a0163ff21433abf7a4afc55524aacba6f7197784ebe3;;
 x86_64) expected=9df110216ff955a4fdad3b0133fe0e92b99d1bc4bcbff80ef31fd30d61c4e19a;;
esac
version=0.1.0-rc4.10
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
