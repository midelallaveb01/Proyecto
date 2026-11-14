<?php
// Ejecutar desde una terminal: php backend/crearAdmin.php
// Nunca se permite crear administradores desde el formulario público.
if (PHP_SAPI !== 'cli') {
	http_response_code(404);
	exit('Este script solo puede ejecutarse desde la terminal.');
}

$configuracion = require __DIR__ . '/config.php';
$baseDatos = new PDO(
	sprintf('mysql:host=%s;dbname=%s;charset=%s', $configuracion['host'], $configuracion['database'], $configuracion['charset']),
	$configuracion['username'],
	$configuracion['password'],
	[PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$nombre = getenv('CACERESGO_ADMIN_NAME') ?: 'Administración Ayuntamiento de Cáceres';
$correo = strtolower(getenv('CACERESGO_ADMIN_EMAIL') ?: 'carolina@aytocaceres.com');
$contrasena = getenv('CACERESGO_ADMIN_PASSWORD');
if (!$contrasena || strlen($contrasena) < 6) {
	fwrite(STDERR, "Define CACERESGO_ADMIN_PASSWORD con al menos 6 caracteres.\n");
	exit(1);
}

$consulta = $baseDatos->prepare('SELECT id FROM users WHERE email = ?');
$consulta->execute([$correo]);
$idExistente = $consulta->fetchColumn();

if ($idExistente) {
	$consulta = $baseDatos->prepare("UPDATE users SET name = ?, password_hash = ?, role = 'admin', status = 'active' WHERE id = ?");
	$consulta->execute([$nombre, password_hash($contrasena, PASSWORD_DEFAULT), $idExistente]);
	echo "Cuenta administradora actualizada: {$correo}\n";
} else {
	$consulta = $baseDatos->prepare("INSERT INTO users (name, email, password_hash, role, status) VALUES (?, ?, ?, 'admin', 'active')");
	$consulta->execute([$nombre, $correo, password_hash($contrasena, PASSWORD_DEFAULT)]);
	echo "Cuenta administradora creada: {$correo}\n";
}
