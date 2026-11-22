//go:build firmy_bind

package firmycore

// Держит libbox и gomobile в списке зависимостей модуля, чтобы `go mod tidy`
// записал их в go.mod/go.sum, а `gomobile bind` (scripts/build-libbox.sh) мог
// собрать libbox и firmycore в один Libbox.xcframework (два Go-рантайма в одном
// процессе не живут). В обычную сборку этот файл не входит (тег firmy_bind).
import (
	_ "github.com/sagernet/gomobile"
	_ "github.com/sagernet/sing-box/experimental/libbox"
)
