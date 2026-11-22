package main

import (
	"embed"
	"os"

	"FirmyVPN/internal/winutil"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/runtime"
)

//go:embed all:frontend/dist
var assets embed.FS

//go:embed build/windows/icon.ico
var appIcon []byte

// Version — версия приложения (для UI и установщика).
const Version = "1.0.0"

func main() {
	// Режим watchdog: наблюдатель за родительским процессом (kill switch).
	if len(os.Args) > 1 && os.Args[1] == "--fvpn-watchdog" {
		block := false
		for _, arg := range os.Args[2:] {
			if arg == "--block-on-death" {
				block = true
			}
		}
		winutil.RunWatchdog(block)
		return
	}

	app := NewApp()

	err := wails.Run(&options.App{
		Title:            "FirmyVPN",
		Width:            1120,
		Height:           740,
		MinWidth:         940,
		MinHeight:        640,
		Frameless:        true,
		BackgroundColour: &options.RGBA{R: 5, G: 7, B: 15, A: 1},
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		OnStartup:  app.startup,
		OnShutdown: app.shutdown,
		SingleInstanceLock: &options.SingleInstanceLock{
			UniqueId: "FirmyVPN-single-instance-7c2f9a1e",
			OnSecondInstanceLaunch: func(data options.SecondInstanceData) {
				if app.ctx != nil {
					runtime.WindowShow(app.ctx)
					runtime.WindowUnminimise(app.ctx)
				}
			},
		},
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
