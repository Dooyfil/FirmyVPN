// Package winutil — Windows-утилиты FirmyVPN: kill switch (брандмауэр),
// автозагрузка, глобальная горячая клавиша.
package winutil

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

const killSwitchRuleName = "FirmyVPN KillSwitch"

func netsh(args ...string) (string, error) {
	cmd := exec.Command("netsh", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("netsh %s: %v (%s)", strings.Join(args, " "), err, strings.TrimSpace(string(out)))
	}
	return string(out), nil
}

// AddKillSwitchRules ставит общее правило блокировки исходящего трафика.
// Внимание: в Windows block-правило сильнее любых allow-правил, поэтому
// блокировка ставится ТОЛЬКО когда туннель не работает (см. engine).
func AddKillSwitchRules() error {
	_, err := netsh("advfirewall", "firewall", "add", "rule",
		"name="+killSwitchRuleName,
		"dir=out", "action=block", "profile=any",
		"description=FirmyVPN kill switch: интернет заблокирован, пока VPN отключён")
	return err
}

// RemoveKillSwitchRules снимает правило блокировки (идемпотентно).
func RemoveKillSwitchRules() error {
	_, err := netsh("advfirewall", "firewall", "delete", "rule", "name="+killSwitchRuleName)
	if err != nil && strings.Contains(err.Error(), "нет") { // правило отсутствует — не ошибка
		return nil
	}
	return err
}

// KillSwitchActive проверяет, стоит ли правило блокировки.
func KillSwitchActive() (bool, error) {
	out, err := netsh("advfirewall", "firewall", "show", "rule", "name="+killSwitchRuleName)
	if err != nil {
		return false, err
	}
	// если правило есть — вывод содержит его имя
	return strings.Contains(out, killSwitchRuleName), nil
}

// ---------- автозагрузка ----------

const runKeyPath = `Software\Microsoft\Windows\CurrentVersion\Run`

// SetAutostart включает/выключает автозапуск (HKCU, без прав админа).
func SetAutostart(enable bool) error {
	key, _, err := registry.CreateKey(registry.CURRENT_USER, runKeyPath, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer key.Close()
	if enable {
		exe, err := os.Executable()
		if err != nil {
			return err
		}
		return key.SetStringValue("FirmyVPN", `"`+exe+`"`)
	}
	err = key.DeleteValue("FirmyVPN")
	if err == registry.ErrNotExist {
		return nil
	}
	return err
}

// ---------- глобальная горячая клавиша ----------

var (
	user32           = windows.NewLazySystemDLL("user32.dll")
	procRegisterHK   = user32.NewProc("RegisterHotKey")
	procUnregisterHK = user32.NewProc("UnregisterHotKey")
	procGetMessage   = user32.NewProc("GetMessageW")
	procPostThread   = user32.NewProc("PostThreadMessageW")

	hotkeyMu      sync.Mutex
	hotkeyThread  uint32
	hotkeyID      = 1
	hotkeyStarted bool
)

const (
	wmHotkey    = 0x0312
	wmQuit      = 0x0012
	modAlt      = 0x0001
	modControl  = 0x0002
	modNoRepeat = 0x4000
)

type winMsg struct {
	Hwnd    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      struct{ X, Y int32 }
}

// StartHotkey регистрирует глобальную клавишу Ctrl+Alt+V и вызывает cb
// при нажатии. cb вызывается в потоке сообщений — не блокировать.
func StartHotkey(cb func()) error {
	hotkeyMu.Lock()
	defer hotkeyMu.Unlock()
	if hotkeyStarted {
		return nil
	}
	done := make(chan uint32, 1)
	errCh := make(chan error, 1)
	go func() {
		runtime.LockOSThread()
		tid := windows.GetCurrentThreadId()
		r1, _, err := procRegisterHK.Call(0, uintptr(hotkeyID),
			uintptr(modControl|modAlt|modNoRepeat), uintptr('V'))
		if r1 == 0 {
			errCh <- fmt.Errorf("RegisterHotKey: %v", err)
			return
		}
		done <- tid
		var msg winMsg
		for {
			r, _, _ := procGetMessage.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
			if int32(r) <= 0 { // WM_QUIT или ошибка
				break
			}
			if msg.Message == wmHotkey && cb != nil {
				cb()
			}
		}
		procUnregisterHK.Call(0, uintptr(hotkeyID))
	}()
	select {
	case tid := <-done:
		hotkeyThread = tid
		hotkeyStarted = true
		return nil
	case err := <-errCh:
		return err
	}
}

// StopHotkey снимает горячую клавишу.
func StopHotkey() {
	hotkeyMu.Lock()
	defer hotkeyMu.Unlock()
	if !hotkeyStarted {
		return
	}
	procPostThread.Call(uintptr(hotkeyThread), wmQuit, 0, 0)
	hotkeyStarted = false
}

// ---------- watchdog kill switch ----------

// RunWatchdog — режим демона: ждёт смерти родительского процесса
// (EOF на stdin) и при kill switch ставит правило блокировки.
// Если родитель прислал "quit" — выходит молча.
func RunWatchdog(blockOnDeath bool) {
	buf := make([]byte, 16)
	gotQuit := false
	for {
		n, err := os.Stdin.Read(buf)
		if n > 0 && strings.Contains(string(buf[:n]), "quit") {
			gotQuit = true
		}
		if err != nil { // родитель умер (EOF) или закрыл канал
			break
		}
	}
	if gotQuit || !blockOnDeath {
		return
	}
	// Родитель упал при включённом kill switch — блокируем интернет.
	_ = AddKillSwitchRules()
}

// SpawnWatchdog запускает дочерний процесс-наблюдатель.
// Возвращает функцию, которую нужно вызвать при graceful-остановке
// (пишет "quit" демону). Если enable=false — демон не блокирует при смерти.
func SpawnWatchdog(enable bool) (quitFn func(), err error) {
	exe, err := os.Executable()
	if err != nil {
		return nil, err
	}
	cmd := exec.Command(exe, "--fvpn-watchdog")
	if enable {
		cmd.Args = append(cmd.Args, "--block-on-death")
	}
	cmd.Dir = filepath.Dir(exe)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	// не даём демону удерживать окно/консоль
	var once sync.Once
	quitFn = func() {
		once.Do(func() {
			_, _ = stdin.Write([]byte("quit"))
			_ = stdin.Close()
			_ = cmd.Process.Kill() // демон уже получил сигнал, просто убираем
		})
	}
	go func() { _, _ = cmd.Process.Wait() }()
	return quitFn, nil
}

// IsAdmin проверяет, запущен ли процесс с правами администратора.
func IsAdmin() bool {
	var sid *windows.SID
	err := windows.AllocateAndInitializeSid(
		&windows.SECURITY_NT_AUTHORITY, 2,
		windows.SECURITY_BUILTIN_DOMAIN_RID, windows.DOMAIN_ALIAS_RID_ADMINS,
		0, 0, 0, 0, 0, 0, &sid)
	if err != nil {
		return false
	}
	defer windows.FreeSid(sid)
	token := windows.Token(0)
	member, err := token.IsMember(sid)
	if err != nil {
		return false
	}
	return member
}
