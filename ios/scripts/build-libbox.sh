#!/usr/bin/env bash
# Собирает Libbox.xcframework (sing-box + ядро FirmyVPN) через gomobile.
# Нужен Mac с Xcode и Go ≥ 1.26. На GitHub это делает .github/workflows/ios.yml.
#
# Один фреймворк — один Go-рантайм (два gomobile-фреймворка в один процесс
# не влезают):
#   - github.com/sagernet/sing-box/experimental/libbox — sing-box 1.14.4
#   - firmyvpn/ios/core                                 — парсер ключей и сборка конфига
# Версии закреплены в core/go.mod. Теги — собственные build_libbox-теги sing-box для Apple.
#
#   bash scripts/build-libbox.sh
#   PLATFORMS=ios bash scripts/build-libbox.sh        # только устройство, быстрее
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORMS="${PLATFORMS:-ios,iossimulator}"
GOMOBILE_VERSION="v0.1.13"

command -v go >/dev/null || { echo "Go не найден: brew install go"; exit 1; }
command -v xcodebuild >/dev/null || { echo "Нужен Xcode"; exit 1; }

go install "github.com/sagernet/gomobile/cmd/gomobile@$GOMOBILE_VERSION"
go install "github.com/sagernet/gomobile/cmd/gobind@$GOMOBILE_VERSION"
export PATH="$(go env GOPATH)/bin:$PATH"

SING_BOX_VERSION="$(cd "$ROOT/core" && go list -m -f '{{.Version}}' github.com/sagernet/sing-box)"
TAGS="with_gvisor,with_quic,with_wireguard,with_utls,with_naive_outbound,with_clash_api,badlinkname,tfogo_checklinkname0"
TAGS="$TAGS,with_dhcp,grpcnotrace,with_low_memory"
LDFLAGS="-X github.com/sagernet/sing-box/constant.Version=${SING_BOX_VERSION#v} -X runtime.godebugDefault=multipathtcp=0,tlssha1=1 -checklinkname=0 -s -w -buildid="

PACKAGES="github.com/sagernet/sing-box/experimental/libbox firmyvpn/ios/core"

mkdir -p "$ROOT/Frameworks"
rm -rf "$ROOT/Frameworks/Libbox.xcframework"
cd "$ROOT/core"
gomobile bind -v \
  -target "$PLATFORMS" \
  -libname=box \
  -iosversion=15.0 \
  -trimpath -buildvcs=false \
  -tags "$TAGS" \
  -ldflags "$LDFLAGS" \
  -o "$ROOT/Frameworks/Libbox.xcframework" \
  $PACKAGES

echo "Готово: $ROOT/Frameworks/Libbox.xcframework (sing-box $SING_BOX_VERSION; пакеты: $PACKAGES)"
echo "Сверьте протоколы: $ROOT/Frameworks/Libbox.xcframework/ios-arm64/Libbox.framework/Headers/"
