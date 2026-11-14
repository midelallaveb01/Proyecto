$ErrorActionPreference = 'Stop'

$php = 'C:\xampp\php\php.exe'
$script = Join-Path $PSScriptRoot 'crearAdmin.php'
if (-not (Test-Path -LiteralPath $php)) {
    $comandoPHP = Get-Command php -ErrorAction SilentlyContinue
    if (-not $comandoPHP) {
        throw 'No se encontró PHP. Comprueba la instalación de XAMPP.'
    }
    $php = $comandoPHP.Source
}

$correo = Read-Host 'Correo del administrador [carolina@aytocaceres.com]'
if ([string]::IsNullOrWhiteSpace($correo)) {
    $correo = 'carolina@aytocaceres.com'
}

$contrasenaSegura = Read-Host 'Contrasena del administrador (minimo 6 caracteres)' -AsSecureString
$punteroContrasena = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($contrasenaSegura)
$contrasena = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($punteroContrasena)
$correoAnterior = $env:CACERESGO_ADMIN_EMAIL
$contrasenaAnterior = $env:CACERESGO_ADMIN_PASSWORD

try {
    if ($contrasena.Length -lt 6) {
        throw 'La contrasena debe tener al menos 6 caracteres.'
    }

    $env:CACERESGO_ADMIN_EMAIL = $correo.Trim().ToLowerInvariant()
    $env:CACERESGO_ADMIN_PASSWORD = $contrasena
    & $php $script
    if ($LASTEXITCODE -ne 0) {
        throw "El script PHP termino con codigo $LASTEXITCODE."
    }
}
finally {
    if ($null -eq $correoAnterior) {
        Remove-Item Env:CACERESGO_ADMIN_EMAIL -ErrorAction SilentlyContinue
    } else {
        $env:CACERESGO_ADMIN_EMAIL = $correoAnterior
    }
    if ($null -eq $contrasenaAnterior) {
        Remove-Item Env:CACERESGO_ADMIN_PASSWORD -ErrorAction SilentlyContinue
    } else {
        $env:CACERESGO_ADMIN_PASSWORD = $contrasenaAnterior
    }
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($punteroContrasena)
    $contrasenaSegura.Dispose()
}
