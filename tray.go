package main

import (
	"os"
	"os/exec"
	"path/filepath"

	"github.com/wailsapp/wails/v2/pkg/runtime"

	"fyne.io/systray"
)

// ---------- системный трей ----------

var (
	trayShow    *systray.MenuItem
	trayConnect *systray.MenuItem
	trayQuit    *systray.MenuItem
	trayReady   bool
)

func startTray(a *App) {
	go systray.Run(func() {
		systray.SetIcon(appIcon)
		systray.SetTitle("FirmyVPN")
		systray.SetTooltip("FirmyVPN — VPN-клиент")

		trayShow = systray.AddMenuItem("Показать FirmyVPN", "Открыть окно")
		trayConnect = systray.AddMenuItem("Подключить", "Быстрое подключение к последнему серверу")
		systray.AddSeparator()
		trayQuit = systray.AddMenuItem("Выход", "Закрыть FirmyVPN")
		trayReady = true

		go func() {
			for {
				select {
				case <-trayShow.ClickedCh:
					runtime.WindowShow(a.ctx)
					runtime.WindowUnminimise(a.ctx)
				case <-trayConnect.ClickedCh:
					go a.ToggleConnect()
				case <-trayQuit.ClickedCh:
					runtime.Quit(a.ctx)
				}
			}
		}()
	}, func() {
		trayReady = false
	})
}

// updateTrayState обновляет пункты меню трея по статусу подключения.
func updateTrayState(connected bool, serverName string) {
	if !trayReady || trayConnect == nil {
		return
	}
	if connected {
		trayConnect.SetTitle("Отключить — " + serverName)
	} else {
		trayConnect.SetTitle("Подключить")
	}
}

func stopTray() {
	if trayReady {
		systray.Quit()
	}
}

// ---------- прочее ----------

// execExplorer открывает папку данных приложения в проводнике.
func execExplorer() error {
	base, err := os.UserConfigDir()
	if err != nil {
		return err
	}
	return exec.Command("explorer", filepath.Join(base, "FirmyVPN")).Start()
}
