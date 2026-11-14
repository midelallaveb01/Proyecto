<?php
// Crea la cuenta del administrador o le cambia la contraseña.
// Se ejecuta desde una terminal, en la carpeta del proyecto: C:\xampp\php\php.exe backend\crearAdmin.php
// Nunca se permite crear administradores desde el formulario público.
if (PHP_SAPI !== 'cli') {
	http_response_code(404);
	exit('Este script solo puede ejecutarse desde la terminal.');
}

// Uso config.php y, si no existe, la plantilla con los datos de XAMPP (igual que db.php).
$archivoConfiguracion = file_exists(__DIR__ . '/config.php') ? __DIR__ . '/config.php' : __DIR__ . '/config.example.php';
$configuracion = require $archivoConfiguracion;
$baseDatos = new PDO(
	sprintf('mysql:host=%s;dbname=%s;charset=%s', $configuracion['host'], $configuracion['database'], $configuracion['charset']),
	$configuracion['username'],
	$configuracion['password'],
	[PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

// Pregunto el correo. Si se deja vacío, uso el del Ayuntamiento.
echo 'Correo del administrador [carolina@aytocaceres.com]: ';
$correo = strtolower(trim(fgets(STDIN)));
if ($correo === '') {
	$correo = 'carolina@aytocaceres.com';
}

// Pregunto la contraseña nueva.
echo 'Contraseña nueva (mínimo 6 caracteres): ';
$contrasena = trim(fgets(STDIN));
if (strlen($contrasena) < 6) {
	echo "La contraseña debe tener al menos 6 caracteres.\n";
	exit(1);
}

$nombre = 'Administración Ayuntamiento de Cáceres';
$consulta = $baseDatos->prepare('SELECT id FROM users WHERE email = ?');
$consulta->execute([$correo]);
$idExistente = $consulta->fetchColumn();

if ($idExistente) {
	$consulta = $baseDatos->prepare("UPDATE users SET password_hash = ?, role = 'admin', status = 'active' WHERE id = ?");
	$consulta->execute([password_hash($contrasena, PASSWORD_DEFAULT), $idExistente]);
	echo "Contraseña cambiada: {$correo}\n";
} else {
	$consulta = $baseDatos->prepare("INSERT INTO users (name, email, password_hash, role, status) VALUES (?, ?, ?, 'admin', 'active')");
	$consulta->execute([$nombre, $correo, password_hash($contrasena, PASSWORD_DEFAULT)]);
	echo "Cuenta de administrador creada: {$correo}\n";
}
