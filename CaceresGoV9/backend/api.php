<?php
// API principal de CaceresGO para MySQL y PHP.
session_start();
header('Content-Type: application/json; charset=utf-8');
// Las respuestas no se guardan en caché: así el navegador y el hosting siempre dan los datos del momento.
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require __DIR__ . '/db.php';

// 1. Funciones comunes
// Leo los datos JSON que envía el navegador.
function leerDatos(): array {
    return json_decode(file_get_contents('php://input'), true) ?: [];
}

// Envío la respuesta en JSON con su código HTTP y termino.
function responder($datos, int $estado = 200): never {
    http_response_code($estado);
    echo json_encode($datos, JSON_UNESCAPED_UNICODE);
    exit;
}

// Devuelvo el usuario de la sesión o null si no hay nadie conectado.
function usuarioConectado(): ?array {
    global $baseDatos;
    $usuario = $_SESSION['usuario'] ?? null;
    if (!$usuario) return null;
    // Compruebo en MySQL que la cuenta sigue activa, por si el administrador la ha bloqueado con la sesión abierta.
    $consulta = $baseDatos->prepare('SELECT status FROM users WHERE id = ?');
    $consulta->execute([$usuario['id']]);
    if ($consulta->fetchColumn() !== 'active') {
        $_SESSION = [];
        session_destroy();
        return null;
    }
    return $usuario;
}

// Solo deja seguir si hay una sesión iniciada.
function exigirUsuario(): array {
    $usuario = usuarioConectado();
    if (!$usuario) responder(['error' => 'Debes iniciar sesión'], 401);
    return $usuario;
}

// Solo deja seguir si la cuenta es de administrador.
function exigirAdministrador(): array {
    $usuario = exigirUsuario();
    if ($usuario['role'] !== 'admin') responder(['error' => 'No tienes permisos de administrador'], 403);
    return $usuario;
}

// 2. Acción pedida desde el navegador
$accion = $_GET['action'] ?? '';
$metodo = $_SERVER['REQUEST_METHOD'];
$datos = leerDatos();

try {
    // 3. Registro, inicio de sesión y perfil
    // Registro de una cuenta nueva de participante.
    if ($accion === 'register' && $metodo === 'POST') {
        $nombre = trim($datos['name'] ?? '');
        $correo = strtolower(trim($datos['email'] ?? ''));
        $contrasena = $datos['password'] ?? '';
        if ($nombre === '' || !filter_var($correo, FILTER_VALIDATE_EMAIL) || strlen($contrasena) < 6) {
            responder(['error' => 'Nombre, correo y contraseña válida son obligatorios'], 422);
        }
        // Las cuentas del Ayuntamiento no se pueden crear desde el registro público.
        if (str_ends_with($correo, '@aytocaceres.com')) {
            responder(['error' => 'Este correo no se puede registrar desde aquí'], 403);
        }
        $consulta = $baseDatos->prepare('INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)');
        try {
            $consulta->execute([$nombre, $correo, password_hash($contrasena, PASSWORD_DEFAULT)]);
        } catch (PDOException $error) {
            if ($error->errorInfo[1] === 1062) responder(['error' => 'Ya existe una cuenta con ese correo'], 409);
            throw $error;
        }
        $id = (int) $baseDatos->lastInsertId();
        session_regenerate_id(true);
        $_SESSION['usuario'] = ['id' => $id, 'name' => $nombre, 'email' => $correo, 'role' => 'participant', 'status' => 'active', 'birth_date' => null, 'city' => null];
        responder(['user' => $_SESSION['usuario']], 201);
    }

    // Inicio de sesión.
    if ($accion === 'login' && $metodo === 'POST') {
        $correo = strtolower(trim($datos['email'] ?? ''));
        $consulta = $baseDatos->prepare('SELECT id, name, email, password_hash, role, status, birth_date, city FROM users WHERE email = ?');
        $consulta->execute([$correo]);
        $usuario = $consulta->fetch();
        if (!$usuario || !password_verify($datos['password'] ?? '', $usuario['password_hash'])) responder(['error' => 'Correo o contraseña incorrectos'], 401);
        if ($usuario['status'] === 'blocked') responder(['error' => 'Esta cuenta está bloqueada'], 403);
        unset($usuario['password_hash']);
        session_regenerate_id(true);
        $_SESSION['usuario'] = $usuario;
        responder(['user' => $usuario]);
    }

    // Cierre de sesión.
    if ($accion === 'logout' && $metodo === 'POST') {
        $_SESSION = [];
        session_destroy();
        responder(['ok' => true]);
    }

    // Usuario conectado ahora mismo.
    if ($accion === 'me' && $metodo === 'GET') responder(['user' => usuarioConectado()]);

    // Cambio de los datos del perfil.
    if ($accion === 'profile' && $metodo === 'PATCH') {
        $usuario = exigirUsuario();
        $nombre = trim($datos['name'] ?? '');
        $fechaNacimiento = trim($datos['birth_date'] ?? '');
        $ciudad = trim($datos['city'] ?? '');
        if ($nombre === '') responder(['error' => 'El nombre es obligatorio'], 422);
        if ($fechaNacimiento !== '' && !preg_match('/^\d{4}-\d{2}-\d{2}$/', $fechaNacimiento)) {
            responder(['error' => 'La fecha de nacimiento no es válida'], 422);
        }
        $consulta = $baseDatos->prepare('UPDATE users SET name = ?, birth_date = ?, city = ? WHERE id = ?');
        $consulta->execute([$nombre, $fechaNacimiento ?: null, $ciudad ?: null, $usuario['id']]);
        $_SESSION['usuario']['name'] = $nombre;
        $_SESSION['usuario']['birth_date'] = $fechaNacimiento ?: null;
        $_SESSION['usuario']['city'] = $ciudad ?: null;
        responder(['user' => $_SESSION['usuario']]);
    }

    // Cambio de contraseña.
    if ($accion === 'password' && $metodo === 'POST') {
        $usuario = exigirUsuario();
        $consulta = $baseDatos->prepare('SELECT password_hash FROM users WHERE id = ?');
        $consulta->execute([$usuario['id']]);
        $hashContrasena = $consulta->fetchColumn();
        $contrasenaActual = $datos['current_password'] ?? '';
        $contrasenaNueva = $datos['new_password'] ?? '';
        if (!$hashContrasena || !password_verify($contrasenaActual, $hashContrasena)) {
            responder(['error' => 'La contraseña actual no es correcta'], 422);
        }
        if (strlen($contrasenaNueva) < 6) {
            responder(['error' => 'La nueva contraseña debe tener al menos 6 caracteres'], 422);
        }
        $consulta = $baseDatos->prepare('UPDATE users SET password_hash = ? WHERE id = ?');
        $consulta->execute([password_hash($contrasenaNueva, PASSWORD_DEFAULT), $usuario['id']]);
        responder(['ok' => true]);
    }

    // 4. Datos públicos: rutas, estadísticas, clasificación y actividad
    // Rutas publicadas con sus lugares (sin las claves de los QR).
    if ($accion === 'routes' && $metodo === 'GET') {
        // Los puntos de cada ruta son la suma de los puntos de sus lugares.
        $consulta = $baseDatos->query("SELECT r.id, r.name, r.description, r.duration, COALESCE(SUM(p.points), 0) AS points, COUNT(p.id) AS total_places FROM routes r LEFT JOIN places p ON p.route_id = r.id WHERE r.status = 'published' GROUP BY r.id ORDER BY r.created_at");
        $rutas = $consulta->fetchAll();
        // Añado a cada ruta sus lugares, con su categoría y sus puntos (sin la clave QR, que es secreta).
        $consulta = $baseDatos->query('SELECT p.route_id, p.name, p.points, p.latitude, p.longitude, c.name AS category_name FROM places p LEFT JOIN categories c ON c.id = p.category_id ORDER BY p.order_index, p.id');
        $lugaresPorRuta = [];
        foreach ($consulta->fetchAll() as $lugar) {
            $lugaresPorRuta[$lugar['route_id']][] = ['name' => $lugar['name'], 'category_name' => $lugar['category_name'], 'points' => $lugar['points'], 'latitude' => $lugar['latitude'], 'longitude' => $lugar['longitude']];
        }
        foreach ($rutas as &$ruta) {
            $ruta['places'] = $lugaresPorRuta[$ruta['id']] ?? [];
        }
        unset($ruta);
        responder(['routes' => $rutas]);
    }

    // Datos generales de la portada.
    if ($accion === 'stats' && $metodo === 'GET') {
        $rutas = $baseDatos->query("SELECT COUNT(*) FROM routes WHERE status = 'published'")->fetchColumn();
        $visitas = $baseDatos->query('SELECT COUNT(*) FROM visits')->fetchColumn();
        $usuarios = $baseDatos->query("SELECT COUNT(*) FROM users WHERE role = 'participant'")->fetchColumn();
        responder(['routes' => (int) $rutas, 'visits' => (int) $visitas, 'users' => (int) $usuarios]);
    }

    // Clasificación general, los 3 mejores del mes y el top 5 de la semana.
    if ($accion === 'ranking' && $metodo === 'GET') {
        // Además de los puntos, cuento los lugares descubiertos y las rutas terminadas de cada persona.
        $consulta = $baseDatos->query('SELECT u.id, u.name, SUM(v.points) AS points, COUNT(v.id) AS places, (SELECT COUNT(*) FROM route_completions rc WHERE rc.user_id = u.id) AS routes FROM visits v JOIN users u ON u.id = v.user_id WHERE u.status = \'active\' GROUP BY u.id, u.name ORDER BY points DESC, u.name LIMIT 20');
        $general = $consulta->fetchAll();
        // Los mejores de un periodo: solo cuentan los lugares validados en los últimos días indicados.
        $mejoresDelPeriodo = function (int $dias, int $limite) use ($baseDatos): array {
            // Los números van escritos en la consulta (son enteros fijos) porque algunos MySQL no aceptan LIMIT con parámetros.
            $consulta = $baseDatos->query('SELECT u.id, u.name, SUM(v.points) AS points, COUNT(v.id) AS places FROM visits v JOIN users u ON u.id = v.user_id WHERE u.status = \'active\' AND v.validated_at >= NOW() - INTERVAL ' . (int) $dias . ' DAY GROUP BY u.id, u.name ORDER BY points DESC, u.name LIMIT ' . (int) $limite);
            return $consulta->fetchAll();
        };
        responder(['ranking' => $general, 'month' => $mejoresDelPeriodo(30, 3), 'week' => $mejoresDelPeriodo(7, 5)]);
    }

    // Últimas visitas validadas, para la actividad de los exploradores.
    if ($accion === 'activity' && $metodo === 'GET') {
        // Últimas visitas validadas por todos. Por privacidad solo enseño el nombre y la inicial del primer apellido.
        $consulta = $baseDatos->query('SELECT u.name, p.name AS place_name, r.name AS route_name, TIMESTAMPDIFF(SECOND, v.validated_at, NOW()) AS seconds_ago, v.points FROM visits v JOIN users u ON u.id = v.user_id JOIN places p ON p.id = v.place_id JOIN routes r ON r.id = v.route_id WHERE u.status = \'active\' ORDER BY v.validated_at DESC, v.id DESC LIMIT 6');
        $actividad = array_map(function (array $fila): array {
            $palabras = preg_split('/\s+/', trim($fila['name']));
            $inicial = isset($palabras[1]) ? (function_exists('mb_substr') ? mb_substr($palabras[1], 0, 1) : preg_replace('/^(.).*$/us', '$1', $palabras[1])) : '';
            $fila['name'] = $palabras[0] . ($inicial !== '' ? " $inicial." : '');
            return $fila;
        }, $consulta->fetchAll());
        responder(['activity' => $actividad]);
    }

    // 5. Progreso y validación de lugares del participante
    // Progreso del participante en su ruta activa.
    if ($accion === 'progress' && $metodo === 'GET') {
        $usuario = exigirUsuario();
        $idRuta = (int) ($_GET['route_id'] ?? 0);
        $consulta = $baseDatos->prepare('SELECT COALESCE(SUM(points), 0) FROM visits WHERE user_id = ?');
        $consulta->execute([$usuario['id']]);
        $puntosTotales = (int) $consulta->fetchColumn();
        $lugares = [];
        $visitados = 0;

        if ($idRuta > 0) {
            $consulta = $baseDatos->prepare('SELECT p.id, p.name, p.points, p.latitude, p.longitude, c.name AS category_name, IF(v.id IS NULL, 0, 1) AS visited FROM places p LEFT JOIN categories c ON c.id = p.category_id LEFT JOIN visits v ON v.place_id = p.id AND v.user_id = ? WHERE p.route_id = ? ORDER BY p.order_index, p.id');
            $consulta->execute([$usuario['id'], $idRuta]);
            $lugares = $consulta->fetchAll();
            foreach ($lugares as &$lugar) {
                $lugar['visited'] = (bool) $lugar['visited'];
                if ($lugar['visited']) $visitados++;
            }
            unset($lugar);
        }

        responder([
            'total_points' => $puntosTotales,
            'route' => [
                'total' => count($lugares),
                'visited' => $visitados,
                'places' => $lugares
            ]
        ]);
    }

    // Validación de un lugar con la clave de su QR.
    if ($accion === 'validate-visit' && $metodo === 'POST') {
        $usuario = exigirUsuario();
        $codigo = strtoupper(trim($datos['qr_code'] ?? ''));
        $consulta = $baseDatos->prepare('SELECT p.id, p.name, p.route_id, p.points, r.name AS route_name FROM places p JOIN routes r ON r.id = p.route_id WHERE p.qr_code = ?');
        $consulta->execute([$codigo]);
        $lugar = $consulta->fetch();
        if (!$lugar) responder(['error' => 'No existe ningún lugar con esa clave'], 404);
        try {
            $consulta = $baseDatos->prepare('INSERT INTO visits (user_id, route_id, place_id, points) VALUES (?, ?, ?, ?)');
            $consulta->execute([$usuario['id'], $lugar['route_id'], $lugar['id'], $lugar['points']]);
        } catch (PDOException $error) {
            if ($error->errorInfo[1] === 1062) responder(['error' => 'Ya habías validado este lugar'], 409);
            throw $error;
        }
        // Si con este lugar ha visitado todos los de la ruta, la guardo como terminada.
        $consulta = $baseDatos->prepare('SELECT COUNT(*) AS total, COUNT(v.id) AS visitados, COALESCE(SUM(v.points), 0) AS puntos FROM places p LEFT JOIN visits v ON v.place_id = p.id AND v.user_id = ? WHERE p.route_id = ?');
        $consulta->execute([$usuario['id'], $lugar['route_id']]);
        $ruta = $consulta->fetch();
        if ((int) $ruta['total'] > 0 && (int) $ruta['visitados'] === (int) $ruta['total']) {
            $consulta = $baseDatos->prepare('INSERT INTO route_completions (user_id, route_id, points) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE points = VALUES(points)');
            $consulta->execute([$usuario['id'], $lugar['route_id'], (int) $ruta['puntos']]);
        }
        responder(['place' => $lugar]);
    }

    // 6. Panel de administración
    // Listado de rutas.
    if ($accion === 'admin-routes' && $metodo === 'GET') {
        exigirAdministrador();
        $rutas = $baseDatos->query('SELECT r.id, r.name, r.description, r.duration, COALESCE(SUM(p.points), 0) AS points, COUNT(p.id) AS total_places, r.status FROM routes r LEFT JOIN places p ON p.route_id = r.id GROUP BY r.id ORDER BY r.created_at')->fetchAll();
        responder(['routes' => $rutas]);
    }

    // Crear o editar una ruta.
    if ($accion === 'admin-route' && in_array($metodo, ['POST', 'PUT'], true)) {
        $administrador = exigirAdministrador();
        $nombre = trim($datos['name'] ?? '');
        if ($nombre === '') responder(['error' => 'El nombre es obligatorio'], 422);
        $estado = in_array($datos['status'] ?? '', ['draft', 'published', 'archived'], true) ? $datos['status'] : 'published';
        if ($metodo === 'POST') {
            $consulta = $baseDatos->prepare('INSERT INTO routes (name, description, duration, status, created_by) VALUES (?, ?, ?, ?, ?)');
            $consulta->execute([$nombre, trim($datos['description'] ?? ''), trim($datos['duration'] ?? ''), $estado, $administrador['id']]);
            responder(['id' => (int) $baseDatos->lastInsertId()], 201);
        }
        $consulta = $baseDatos->prepare('UPDATE routes SET name = ?, description = ?, duration = ?, status = ? WHERE id = ?');
        $consulta->execute([$nombre, trim($datos['description'] ?? ''), trim($datos['duration'] ?? ''), $estado, (int) ($_GET['id'] ?? 0)]);
        responder(['ok' => true]);
    }

    // Borrar una ruta.
    if ($accion === 'admin-route' && $metodo === 'DELETE') {
        exigirAdministrador();
        $consulta = $baseDatos->prepare('DELETE FROM routes WHERE id = ?');
        $consulta->execute([(int) ($_GET['id'] ?? 0)]);
        responder(['ok' => true]);
    }

    // Lugares de una ruta.
    if ($accion === 'admin-places' && $metodo === 'GET') {
        exigirAdministrador();
        $consulta = $baseDatos->prepare('SELECT p.id, p.route_id, p.category_id, c.name AS category_name, p.name, p.qr_code, p.points, p.order_index FROM places p LEFT JOIN categories c ON c.id = p.category_id WHERE p.route_id = ? ORDER BY p.order_index');
        $consulta->execute([(int) ($_GET['route_id'] ?? 0)]);
        responder(['places' => $consulta->fetchAll()]);
    }

    // Crear o editar un lugar.
    if ($accion === 'admin-place' && in_array($metodo, ['POST', 'PUT'], true)) {
        exigirAdministrador();
        // Los puntos del lugar son siempre los de su categoría.
        $consulta = $baseDatos->prepare('SELECT id, points FROM categories WHERE id = ?');
        $consulta->execute([(int) ($datos['category_id'] ?? 0)]);
        $categoria = $consulta->fetch();
        if (!$categoria) responder(['error' => 'Elige una categoría para el lugar'], 422);
        $valores = [trim($datos['name'] ?? ''), strtoupper(trim($datos['qr_code'] ?? '')), (int) $categoria['points'], (int) ($datos['route_id'] ?? 0), (int) $categoria['id']];
        if ($valores[0] === '' || $valores[1] === '') responder(['error' => 'El nombre y la clave QR son obligatorios'], 422);
        $consulta = $baseDatos->prepare('SELECT COUNT(*) FROM routes WHERE id = ?');
        $consulta->execute([$valores[3]]);
        if (!$consulta->fetchColumn()) responder(['error' => 'La ruta no existe'], 422);
        try {
            if ($metodo === 'POST') {
                // Cada lugar nuevo se coloca el último de su ruta.
                $consulta = $baseDatos->prepare('SELECT COALESCE(MAX(order_index), 0) + 1 FROM places WHERE route_id = ?');
                $consulta->execute([$valores[3]]);
                $orden = (int) $consulta->fetchColumn();
                $consulta = $baseDatos->prepare('INSERT INTO places (name, qr_code, points, route_id, category_id, order_index) VALUES (?, ?, ?, ?, ?, ?)');
                $consulta->execute([...$valores, $orden]);
                responder(['id' => (int) $baseDatos->lastInsertId()], 201);
            }
            $consulta = $baseDatos->prepare('UPDATE places SET name = ?, qr_code = ?, points = ?, route_id = ?, category_id = ? WHERE id = ?');
            $consulta->execute([...$valores, (int) ($_GET['id'] ?? 0)]);
            responder(['ok' => true]);
        } catch (PDOException $error) {
            if ($error->errorInfo[1] === 1062) responder(['error' => 'Ya existe un lugar con esa clave QR'], 409);
            throw $error;
        }
    }

    // Borrar un lugar.
    if ($accion === 'admin-place' && $metodo === 'DELETE') {
        exigirAdministrador();
        $consulta = $baseDatos->prepare('DELETE FROM places WHERE id = ?');
        $consulta->execute([(int) ($_GET['id'] ?? 0)]);
        responder(['ok' => true]);
    }

    // Listado de categorías.
    if ($accion === 'admin-categories' && $metodo === 'GET') {
        exigirAdministrador();
        $categorias = $baseDatos->query('SELECT c.id, c.name, c.points, COUNT(p.id) AS total_places FROM categories c LEFT JOIN places p ON p.category_id = c.id GROUP BY c.id, c.name, c.points ORDER BY c.points DESC, c.name')->fetchAll();
        responder(['categories' => $categorias]);
    }

    // Crear o editar una categoría.
    if ($accion === 'admin-category' && in_array($metodo, ['POST', 'PUT'], true)) {
        exigirAdministrador();
        $nombre = trim($datos['name'] ?? '');
        $puntos = (int) ($datos['points'] ?? -1);
        if ($nombre === '' || $puntos < 0) responder(['error' => 'El nombre y los puntos de la categoría son obligatorios'], 422);
        try {
            if ($metodo === 'POST') {
                $consulta = $baseDatos->prepare('INSERT INTO categories (name, points) VALUES (?, ?)');
                $consulta->execute([$nombre, $puntos]);
                responder(['id' => (int) $baseDatos->lastInsertId()], 201);
            }
            $idCategoria = (int) ($_GET['id'] ?? 0);
            $consulta = $baseDatos->prepare('UPDATE categories SET name = ?, points = ? WHERE id = ?');
            $consulta->execute([$nombre, $puntos, $idCategoria]);
            // Si cambian los puntos de la categoría, cambian también los de todos sus lugares.
            $consulta = $baseDatos->prepare('UPDATE places SET points = ? WHERE category_id = ?');
            $consulta->execute([$puntos, $idCategoria]);
            responder(['ok' => true]);
        } catch (PDOException $error) {
            if ($error->errorInfo[1] === 1062) responder(['error' => 'Ya existe una categoría con ese nombre'], 409);
            throw $error;
        }
    }

    // Borrar una categoría.
    if ($accion === 'admin-category' && $metodo === 'DELETE') {
        exigirAdministrador();
        $idCategoria = (int) ($_GET['id'] ?? 0);
        $consulta = $baseDatos->prepare('SELECT COUNT(*) FROM places WHERE category_id = ?');
        $consulta->execute([$idCategoria]);
        if ($consulta->fetchColumn() > 0) responder(['error' => 'No se puede eliminar: hay lugares con esta categoría'], 409);
        $consulta = $baseDatos->prepare('DELETE FROM categories WHERE id = ?');
        $consulta->execute([$idCategoria]);
        responder(['ok' => true]);
    }

    // Listado de cuentas.
    if ($accion === 'admin-users' && $metodo === 'GET') {
        exigirAdministrador();
        $usuarios = $baseDatos->query('SELECT id, name, email, role, status, created_at FROM users ORDER BY created_at')->fetchAll();
        responder(['users' => $usuarios]);
    }

    // Bloquear o desbloquear una cuenta.
    if ($accion === 'admin-user-status' && $metodo === 'PATCH') {
        $administrador = exigirAdministrador();
        // El administrador no puede bloquear su propia cuenta, porque se quedaría sin acceso al panel.
        if ((int) ($_GET['id'] ?? 0) === (int) $administrador['id']) {
            responder(['error' => 'No puedes bloquear tu propia cuenta'], 403);
        }
        $estado = ($datos['status'] ?? '') === 'blocked' ? 'blocked' : 'active';
        $consulta = $baseDatos->prepare('UPDATE users SET status = ? WHERE id = ?');
        $consulta->execute([$estado, (int) ($_GET['id'] ?? 0)]);
        responder(['ok' => true]);
    }

    // Rutas terminadas por los participantes.
    if ($accion === 'admin-results' && $metodo === 'GET') {
        exigirAdministrador();
        $consulta = $baseDatos->query('SELECT c.points, c.completed_at, u.name AS user_name, r.name AS route_name FROM route_completions c JOIN users u ON u.id = c.user_id JOIN routes r ON r.id = c.route_id ORDER BY c.completed_at DESC');
        responder(['results' => $consulta->fetchAll()]);
    }

    responder(['error' => 'Acción no encontrada'], 404);
} catch (Throwable $error) {
    // En el propio ordenador (XAMPP) enseño el motivo real del error para poder arreglarlo. En internet, no.
    $enLocal = in_array($_SERVER['REMOTE_ADDR'] ?? '', ['127.0.0.1', '::1'], true);
    responder(['error' => $enLocal ? 'Error interno del servidor: ' . $error->getMessage() : 'Error interno del servidor'], 500);
}
