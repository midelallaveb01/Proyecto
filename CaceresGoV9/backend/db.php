<?php
// Abre una única conexión PDO para todos los endpoints del backend.
// Uso config.php. Si no existe (por ejemplo, al copiar la carpeta en XAMPP), uso la plantilla, que ya trae los datos de XAMPP.
$archivoConfiguracion = file_exists(__DIR__ . '/config.php') ? __DIR__ . '/config.php' : __DIR__ . '/config.example.php';
if (!file_exists($archivoConfiguracion)) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['error' => 'Falta backend/config.php. Copia backend/config.example.php con el nombre config.php y pon tus datos de MySQL.']);
    exit;
}
$configuracion = require $archivoConfiguracion;

$cadenaConexion = sprintf(
    'mysql:host=%s;dbname=%s;charset=%s',
    $configuracion['host'],
    $configuracion['database'],
    $configuracion['charset']
);

try {
    $baseDatos = new PDO($cadenaConexion, $configuracion['username'], $configuracion['password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]);
} catch (PDOException $error) {
    http_response_code(500);
    header('Content-Type: application/json; charset=utf-8');
    // Explico el motivo para saber qué hay que revisar, sin enseñar la contraseña.
    $motivos = [
        1045 => 'el usuario o la contraseña de backend/config.php no son correctos',
        1049 => "la base de datos '{$configuracion['database']}' no existe: impórtala en phpMyAdmin",
        2002 => 'MySQL no está encendido o el host de backend/config.php no es correcto'
    ];
    $motivo = $motivos[$error->errorInfo[1] ?? 0] ?? $motivos[(int) $error->getCode()] ?? 'revisa los datos de backend/config.php';
    echo json_encode(['error' => "No se pudo conectar con MySQL: $motivo."]);
    exit;
}
