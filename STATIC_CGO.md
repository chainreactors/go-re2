# Static CGO backend

The `re2_static` build tag complements `re2_cgo` on Windows amd64. It links a
prebuilt RE2 + CRE2 archive and statically links the MinGW C++ runtime so
applications do not require RE2, libstdc++, libgcc, or winpthread DLLs at
runtime.

The bundled archive uses RE2 `2023-03-01`, the final release before RE2 added
its Abseil dependency. This keeps the archive small and avoids MinGW pthread
shutdown instability while retaining the API used by CRE2.

Regenerate the archive from source with:

```powershell
pwsh -File scripts/build-static-windows.ps1
```

Build consumers with both tags:

```text
re2_cgo re2_static
```
