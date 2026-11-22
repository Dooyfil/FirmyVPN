package firmycore

import (
	"net"
	"time"
)

// pingTCP — TCP-пинг сервера: как в PC-версии, соединение к host:port.
func pingTCP(host string, port int, timeoutMs int) int32 {
	if timeoutMs <= 0 {
		timeoutMs = 3000
	}
	addr := net.JoinHostPort(host, itoa(port))
	start := time.Now()
	conn, err := net.DialTimeout("tcp", addr, time.Duration(timeoutMs)*time.Millisecond)
	if err != nil {
		return -1
	}
	_ = conn.Close()
	return int32(time.Since(start).Milliseconds())
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var buf [8]byte
	i := len(buf)
	neg := n < 0
	if neg {
		n = -n
	}
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
