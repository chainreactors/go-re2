//go:build re2_cgo && re2_static && windows && amd64

package cre2

/*
#include "cre2.h"
#cgo LDFLAGS: -L${SRCDIR}/lib/windows_amd64 -lre2_cre2 -static-libgcc -Wl,-Bstatic -lstdc++ -lwinpthread -Wl,-Bdynamic
*/
import "C"
