<?php
// Pruebas automáticas de la API de CaceresGO. Solo para usar en localhost: no subir esta carpeta al hosting.
if (!in_array($_SERVER['REMOTE_ADDR'] ?? '', ['127.0.0.1', '::1'], true)) {
    http_response_code(403);
    exit('Las pruebas solo se pueden abrir desde este ordenador (localhost).');
}

// Conecto con MySQL con los mismos datos que la aplicación. Si falla, lo explico en la página en vez de pararme.
$problemaConexion = '';
// Si no existe config.php, uso la plantilla, igual que la aplicación.
$configuracion = @include __DIR__ . (file_exists(__DIR__ . '/../backend/config.php') ? '/../backend/config.php' : '/../backend/config.example.php');
try {
    if (!is_array($configuracion)) throw new Exception('Falta backend/config.php');
    $baseDatos = new PDO(
        sprintf('mysql:host=%s;dbname=%s;charset=%s', $configuracion['host'], $configuracion['database'], $configuracion['charset']),
        $configuracion['username'],
        $configuracion['password'],
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
    );
} catch (Throwable $error) {
    $problemaConexion = 'No puedo conectar con MySQL. Comprueba que MySQL está encendido en XAMPP y que existe backend/config.php con tus datos.';
}

// 1. Peticiones a la API como si fuera el navegador
$urlAPI = 'http://' . $_SERVER['HTTP_HOST'] . dirname(dirname($_SERVER['SCRIPT_NAME'])) . '/backend/api.php';
$cookies = [];

function peticion(string $quien, string $metodo, string $accion, ?array $datos = null, array $parametros = []): array {
    global $urlAPI, $cookies;
    $url = $urlAPI . '?' . http_build_query(['action' => $accion] + $parametros);
    $cabeceras = "Content-Type: application/json\r\n";
    if (!empty($cookies[$quien])) $cabeceras .= 'Cookie: ' . $cookies[$quien] . "\r\n";
    $contexto = stream_context_create(['http' => [
        'method' => $metodo,
        'header' => $cabeceras,
        'content' => $datos === null ? '' : json_encode($datos),
        'ignore_errors' => true,
        'timeout' => 15
    ]]);
    $cuerpo = @file_get_contents($url, false, $contexto);
    $cabecerasRespuesta = $http_response_header ?? [];
    preg_match('/\s(\d{3})\s/', $cabecerasRespuesta[0] ?? '', $codigo);
    // Guardo la cookie de sesión para que cada "persona" mantenga su propia sesión.
    foreach ($cabecerasRespuesta as $linea) {
        if (preg_match('/^Set-Cookie:\s*([^=]+)=([^;]*)/i', $linea, $cookie)) {
            $cookies[$quien] = $cookie[2] === 'deleted' ? '' : $cookie[1] . '=' . $cookie[2];
        }
    }
    return [(int) ($codigo[1] ?? 0), json_decode($cuerpo ?: 'null', true)];
}

// 2. Registro de resultados
$resultados = [];
$seccionActual = '';

function seccion(string $titulo): void {
    global $seccionActual;
    $seccionActual = $titulo;
}

function comprobar(string $prueba, string $esperado, string $obtenido, bool $correcta): void {
    global $resultados, $seccionActual;
    $resultados[$seccionActual][] = ['prueba' => $prueba, 'esperado' => $esperado, 'obtenido' => $obtenido, 'correcta' => $correcta];
}

function comprobarEstado(string $prueba, int $esperado, array $respuesta): void {
    [$estado, $datos] = $respuesta;
    $detalle = is_array($datos) && isset($datos['error']) ? " · {$datos['error']}" : '';
    comprobar($prueba, "Código $esperado", "Código $estado$detalle", $estado === $esperado);
}

// 3. Ejecución de las pruebas
$ejecutar = $_SERVER['REQUEST_METHOD'] === 'POST';
$problema = '';
$correoAdmin = trim($_POST['admin_email'] ?? 'carolina@aytocaceres.com');
$claveAdmin = $_POST['admin_password'] ?? '';

if ($ejecutar) {
    $sello = date('His');
    $correo = "prueba.automatica.$sello@test.com";
    $nombreCategoria = "Categoría de prueba $sello";
    $nombreRuta = "Ruta de prueba $sello";
    $claveLugar = "PRUEBA$sello";

    // Antes de empezar, compruebo que PHP puede llamar a la API.
    $problema = $problemaConexion;
    if ($problema !== '') {
        // Sin base de datos no se puede probar nada.
    } elseif (!ini_get('allow_url_fopen')) {
        $problema = 'PHP no puede abrir direcciones web. En C:\\xampp\\php\\php.ini pon allow_url_fopen=On y reinicia Apache.';
    } else {
        [$estadoPrueba, $datosPrueba] = peticion('visitante', 'GET', 'stats');
        if ($estadoPrueba !== 200) {
            $problema = "No he podido llamar a la API en $urlAPI (código $estadoPrueba" . (isset($datosPrueba['error']) ? ': ' . $datosPrueba['error'] : '') . ').';
        }
    }

    if ($problema === '') try {
        seccion('Datos públicos');
        $respuesta = peticion('visitante', 'GET', 'routes');
        $rutas = $respuesta[1]['routes'] ?? [];
        comprobar('Ver las rutas publicadas', 'Al menos una ruta', count($rutas) . ' rutas', $respuesta[0] === 200 && count($rutas) > 0);
        comprobar('Las rutas públicas no enseñan las claves QR', 'Sin claves', strpos(json_encode($rutas), 'qr_code') === false ? 'Sin claves' : 'Aparecen claves', strpos(json_encode($rutas), 'qr_code') === false);
        $rutaSumaBien = true;
        foreach ($rutas as $ruta) {
            if ((int) $ruta['points'] !== array_sum(array_column($ruta['places'], 'points'))) $rutaSumaBien = false;
        }
        comprobar('Los puntos de cada ruta son la suma de sus lugares', 'Cuadran', $rutaSumaBien ? 'Cuadran' : 'No cuadran', $rutaSumaBien);
        comprobarEstado('Ver las estadísticas', 200, peticion('visitante', 'GET', 'stats'));
        comprobarEstado('Ver la clasificación', 200, peticion('visitante', 'GET', 'ranking'));
        comprobarEstado('Pedir una acción que no existe', 404, peticion('visitante', 'GET', 'no-existe'));

        seccion('Registro e inicio de sesión');
        comprobarEstado('Registrarse con datos correctos', 201, peticion('participante', 'POST', 'register', ['name' => 'Prueba Automática', 'email' => $correo, 'password' => 'clave1234']));
        comprobarEstado('Registrarse con un correo ya usado', 409, peticion('otro', 'POST', 'register', ['name' => 'Otra', 'email' => $correo, 'password' => 'clave1234']));
        comprobarEstado('Registrarse con un correo @aytocaceres.com', 403, peticion('otro', 'POST', 'register', ['name' => 'Otra', 'email' => "prueba$sello@aytocaceres.com", 'password' => 'clave1234']));
        comprobarEstado('Registrarse con una contraseña de menos de 6 caracteres', 422, peticion('otro', 'POST', 'register', ['name' => 'Otra', 'email' => "otra$sello@test.com", 'password' => '123']));
        comprobarEstado('Iniciar sesión con la contraseña mal', 401, peticion('otro', 'POST', 'login', ['email' => $correo, 'password' => 'incorrecta']));
        $respuesta = peticion('participante', 'GET', 'me');
        comprobar('La sesión se mantiene después de registrarse', 'Su nombre', $respuesta[1]['user']['name'] ?? 'Sin sesión', ($respuesta[1]['user']['email'] ?? '') === $correo);

        seccion('Participante: rutas y validación');
        // Elijo la ruta con menos lugares para completarla entera.
        $rutaPrueba = $baseDatos->query("SELECT r.id, r.name, COUNT(p.id) AS total FROM routes r JOIN places p ON p.route_id = r.id WHERE r.status = 'published' GROUP BY r.id ORDER BY total, r.id LIMIT 1")->fetch();
        $consulta = $baseDatos->prepare('SELECT p.qr_code, p.points, c.points AS category_points FROM places p LEFT JOIN categories c ON c.id = p.category_id WHERE p.route_id = ? ORDER BY p.order_index');
        $consulta->execute([$rutaPrueba['id']]);
        $lugaresRuta = $consulta->fetchAll();
        comprobarEstado('Validar una clave sin iniciar sesión', 401, peticion('visitante', 'POST', 'validate-visit', ['qr_code' => $lugaresRuta[0]['qr_code']]));
        comprobarEstado('Validar una clave que no existe', 404, peticion('participante', 'POST', 'validate-visit', ['qr_code' => 'NOEXISTE']));
        $respuesta = peticion('participante', 'POST', 'validate-visit', ['qr_code' => strtolower($lugaresRuta[0]['qr_code'])]);
        comprobar('Validar una clave correcta (en minúsculas)', 'Código 200 y ' . $lugaresRuta[0]['category_points'] . ' puntos', "Código {$respuesta[0]} y " . ($respuesta[1]['place']['points'] ?? '?') . ' puntos', $respuesta[0] === 200 && (int) ($respuesta[1]['place']['points'] ?? -1) === (int) $lugaresRuta[0]['category_points']);
        comprobarEstado('Validar la misma clave otra vez', 409, peticion('participante', 'POST', 'validate-visit', ['qr_code' => $lugaresRuta[0]['qr_code']]));
        foreach (array_slice($lugaresRuta, 1) as $lugar) peticion('participante', 'POST', 'validate-visit', ['qr_code' => $lugar['qr_code']]);
        $respuesta = peticion('participante', 'GET', 'progress', null, ['route_id' => $rutaPrueba['id']]);
        $visitados = $respuesta[1]['route']['visited'] ?? 0;
        comprobar("Completar «{$rutaPrueba['name']}» sin iniciarla", "{$rutaPrueba['total']} de {$rutaPrueba['total']} lugares", "$visitados de {$rutaPrueba['total']} lugares", (int) $visitados === (int) $rutaPrueba['total']);
        $consulta = $baseDatos->prepare('SELECT COUNT(*) FROM route_completions rc JOIN users u ON u.id = rc.user_id WHERE u.email = ? AND rc.route_id = ?');
        $consulta->execute([$correo, $rutaPrueba['id']]);
        $terminada = (int) $consulta->fetchColumn();
        comprobar('La ruta terminada se guarda en Resultados', 'Guardada', $terminada ? 'Guardada' : 'No guardada', $terminada === 1);
        $respuesta = peticion('visitante', 'GET', 'ranking');
        $enClasificacion = in_array('Prueba Automática', array_column($respuesta[1]['ranking'] ?? [], 'name'), true);
        comprobar('Aparece en la clasificación', 'Aparece', $enClasificacion ? 'Aparece' : 'No aparece', $enClasificacion);

        seccion('Participante: perfil y contraseña');
        comprobarEstado('Guardar ciudad y fecha de nacimiento', 200, peticion('participante', 'PATCH', 'profile', ['name' => 'Prueba Automática', 'city' => 'Cáceres', 'birth_date' => '2000-01-01']));
        comprobarEstado('Guardar una fecha con formato incorrecto', 422, peticion('participante', 'PATCH', 'profile', ['name' => 'Prueba Automática', 'birth_date' => '01/01/2000']));
        comprobarEstado('Cambiar la contraseña con la actual mal', 422, peticion('participante', 'POST', 'password', ['current_password' => 'mal', 'new_password' => 'clave5678']));
        comprobarEstado('Cambiar la contraseña correctamente', 200, peticion('participante', 'POST', 'password', ['current_password' => 'clave1234', 'new_password' => 'clave5678']));
        comprobarEstado('Entrar con la contraseña nueva', 200, peticion('otro', 'POST', 'login', ['email' => $correo, 'password' => 'clave5678']));

        seccion('Permisos');
        comprobarEstado('Un participante pide las cuentas del panel', 403, peticion('participante', 'GET', 'admin-users'));
        comprobarEstado('Alguien sin sesión pide los recorridos del panel', 401, peticion('visitante', 'GET', 'admin-routes'));

        seccion('Administrador');
        $respuesta = peticion('admin', 'POST', 'login', ['email' => $correoAdmin, 'password' => $claveAdmin]);
        comprobar('Entrar con la cuenta del Ayuntamiento', 'Código 200 y rol admin', "Código {$respuesta[0]} y rol " . ($respuesta[1]['user']['role'] ?? '-'), $respuesta[0] === 200 && ($respuesta[1]['user']['role'] ?? '') === 'admin');
        $idAdmin = (int) ($respuesta[1]['user']['id'] ?? 0);
        comprobarEstado('Ver los recorridos del panel', 200, peticion('admin', 'GET', 'admin-routes'));
        comprobarEstado('Ver las categorías', 200, peticion('admin', 'GET', 'admin-categories'));
        comprobarEstado('Ver las cuentas', 200, peticion('admin', 'GET', 'admin-users'));
        comprobarEstado('Ver los resultados', 200, peticion('admin', 'GET', 'admin-results'));
        comprobarEstado('Crear una categoría', 201, peticion('admin', 'POST', 'admin-category', ['name' => $nombreCategoria, 'points' => 25]));
        comprobarEstado('Crear una categoría con un nombre repetido', 409, peticion('admin', 'POST', 'admin-category', ['name' => $nombreCategoria, 'points' => 10]));
        $consulta = $baseDatos->prepare('SELECT id FROM categories WHERE name = ?');
        $consulta->execute([$nombreCategoria]);
        $idCategoria = (int) $consulta->fetchColumn();
        $respuesta = peticion('admin', 'POST', 'admin-route', ['name' => $nombreRuta, 'description' => 'Ruta creada por las pruebas.', 'duration' => '10 min', 'status' => 'draft']);
        comprobarEstado('Crear un recorrido', 201, $respuesta);
        $idRuta = (int) ($respuesta[1]['id'] ?? 0);
        comprobarEstado('Añadir un lugar sin categoría', 422, peticion('admin', 'POST', 'admin-place', ['name' => 'Lugar de prueba', 'qr_code' => $claveLugar, 'route_id' => $idRuta]));
        $respuesta = peticion('admin', 'POST', 'admin-place', ['name' => 'Lugar de prueba', 'qr_code' => $claveLugar, 'route_id' => $idRuta, 'category_id' => $idCategoria, 'points' => 999]);
        comprobarEstado('Añadir un lugar con categoría', 201, $respuesta);
        $idLugar = (int) ($respuesta[1]['id'] ?? 0);
        $consulta = $baseDatos->prepare('SELECT points FROM places WHERE id = ?');
        $consulta->execute([$idLugar]);
        $puntosLugar = (int) $consulta->fetchColumn();
        comprobar('El lugar toma los puntos de su categoría (no los 999 enviados)', '25 puntos', "$puntosLugar puntos", $puntosLugar === 25);
        comprobarEstado('Añadir un lugar con una clave QR repetida', 409, peticion('admin', 'POST', 'admin-place', ['name' => 'Otro', 'qr_code' => $claveLugar, 'route_id' => $idRuta, 'category_id' => $idCategoria]));
        comprobarEstado('Cambiar los puntos de la categoría a 30', 200, peticion('admin', 'PUT', 'admin-category', ['name' => $nombreCategoria, 'points' => 30], ['id' => $idCategoria]));
        $consulta->execute([$idLugar]);
        $puntosLugar = (int) $consulta->fetchColumn();
        comprobar('Sus lugares pasan a 30 puntos', '30 puntos', "$puntosLugar puntos", $puntosLugar === 30);
        $respuesta = peticion('admin', 'GET', 'admin-routes');
        $rutaCreada = array_values(array_filter($respuesta[1]['routes'] ?? [], fn($ruta) => (int) $ruta['id'] === $idRuta))[0] ?? [];
        comprobar('Los puntos del recorrido se calculan solos', '1 lugar y 30 puntos', ($rutaCreada['total_places'] ?? '?') . ' lugar y ' . ($rutaCreada['points'] ?? '?') . ' puntos', (int) ($rutaCreada['points'] ?? -1) === 30);
        comprobarEstado('Eliminar una categoría que tiene lugares', 409, peticion('admin', 'DELETE', 'admin-category', null, ['id' => $idCategoria]));
        comprobarEstado('Eliminar el lugar', 200, peticion('admin', 'DELETE', 'admin-place', null, ['id' => $idLugar]));
        comprobarEstado('Eliminar la categoría ya sin lugares', 200, peticion('admin', 'DELETE', 'admin-category', null, ['id' => $idCategoria]));
        comprobarEstado('Eliminar el recorrido', 200, peticion('admin', 'DELETE', 'admin-route', null, ['id' => $idRuta]));
        comprobarEstado('El administrador intenta bloquear su propia cuenta', 403, peticion('admin', 'PATCH', 'admin-user-status', ['status' => 'blocked'], ['id' => $idAdmin]));

        seccion('Bloqueo de una cuenta con la sesión abierta');
        $consulta = $baseDatos->prepare('SELECT id FROM users WHERE email = ?');
        $consulta->execute([$correo]);
        $idParticipante = (int) $consulta->fetchColumn();
        comprobarEstado('El administrador bloquea al participante', 200, peticion('admin', 'PATCH', 'admin-user-status', ['status' => 'blocked'], ['id' => $idParticipante]));
        comprobarEstado('El participante, sin cerrar sesión, intenta validar', 401, peticion('participante', 'POST', 'validate-visit', ['qr_code' => $lugaresRuta[0]['qr_code']]));
        comprobarEstado('El participante intenta volver a entrar', 403, peticion('participante', 'POST', 'login', ['email' => $correo, 'password' => 'clave5678']));
        comprobarEstado('El administrador vuelve a activar la cuenta', 200, peticion('admin', 'PATCH', 'admin-user-status', ['status' => 'active'], ['id' => $idParticipante]));
        comprobarEstado('El participante puede entrar de nuevo', 200, peticion('participante', 'POST', 'login', ['email' => $correo, 'password' => 'clave5678']));
        comprobarEstado('Cerrar sesión', 200, peticion('participante', 'POST', 'logout'));
    } catch (Throwable $error) {
        comprobar('Las pruebas se han parado por un error', 'Sin errores', $error->getMessage(), false);
    } finally {
        // Borro todo lo que han creado las pruebas. Sus visitas y resultados se borran en cascada.
        $baseDatos->prepare('DELETE FROM users WHERE email = ?')->execute([$correo]);
        $baseDatos->prepare('DELETE FROM places WHERE qr_code = ?')->execute([$claveLugar]);
        $baseDatos->prepare('DELETE FROM routes WHERE name = ?')->execute([$nombreRuta]);
        $baseDatos->prepare('DELETE FROM categories WHERE name = ?')->execute([$nombreCategoria]);
    }
}

$total = array_sum(array_map('count', $resultados));
$correctas = 0;
foreach ($resultados as $filas) $correctas += count(array_filter($filas, fn($fila) => $fila['correcta']));
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Pruebas · CáceresGO</title>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=DM+Sans:opsz,wght@9..40,400;9..40,500;9..40,700&family=Playfair+Display:wght@600&display=swap">
  <style>
    body {margin:0; background:#f8f5ed; color:#102b2a; font:15px 'DM Sans',sans-serif}
    main {max-width:1000px; margin:auto; padding:36px 20px 60px}
    h1 {font:600 40px 'Playfair Display',serif; margin:0 0 8px}
    h2 {font:600 22px 'Playfair Display',serif; margin:30px 0 10px}
    .aviso {color:#5d6f6c; margin:0 0 22px}
    form {display:flex; flex-wrap:wrap; gap:10px; align-items:end; background:#f1ece1; padding:18px; margin-bottom:24px}
    label {display:grid; gap:5px; font-size:12px; font-weight:700}
    input {padding:10px; border:1px solid #d8d0bf; font:14px 'DM Sans',sans-serif; min-width:220px}
    button {background:#ee6b54; color:#fff; border:0; padding:12px 18px; font:700 14px 'DM Sans',sans-serif; cursor:pointer}
    .resumen {font:500 15px 'DM Mono',monospace; padding:12px 16px; color:#fff}
    .resumen.bien {background:#174842}
    .resumen.mal {background:#b13d2d}
    table {width:100%; border-collapse:collapse; background:#fff}
    th,td {text-align:left; padding:9px 11px; border-bottom:1px solid #eee7d8; vertical-align:top; font-size:13.5px}
    th {font:500 11px 'DM Mono',monospace; text-transform:uppercase; letter-spacing:.6px; color:#5d6f6c}
    .estado {font-weight:700; width:24px}
    .correcta {color:#1d7a3a}
    .fallida {color:#b13d2d}
    a {color:#174842}
  </style>
</head>
<body>
<main>
  <h1>Pruebas de CáceresGO</h1>
  <p class="aviso">Comprueba la API contra tu base de datos de XAMPP. Crea una cuenta, una categoría, una ruta y un lugar de prueba y los borra al terminar. Tus datos no se tocan. <a href="../">Volver a la aplicación</a></p>
  <form method="post">
    <label>Correo del administrador<input name="admin_email" value="<?= htmlspecialchars($correoAdmin) ?>"></label>
    <label>Contraseña del administrador<input name="admin_password" type="password" value="<?= htmlspecialchars($claveAdmin) ?>"></label>
    <button type="submit">▶ Ejecutar las pruebas</button>
  </form>
<?php if ($ejecutar && $problema !== ''): ?>
  <p class="resumen mal"><?= htmlspecialchars($problema) ?></p>
<?php elseif ($ejecutar): ?>
  <p class="resumen <?= $correctas === $total ? 'bien' : 'mal' ?>"><?= $correctas ?> de <?= $total ?> pruebas correctas</p>
<?php foreach ($resultados as $titulo => $filas): ?>
  <h2><?= htmlspecialchars($titulo) ?></h2>
  <table>
    <tr><th></th><th>Prueba</th><th>Esperado</th><th>Obtenido</th></tr>
<?php foreach ($filas as $fila): ?>
    <tr><td class="estado <?= $fila['correcta'] ? 'correcta' : 'fallida' ?>"><?= $fila['correcta'] ? '✔' : '✘' ?></td><td><?= htmlspecialchars($fila['prueba']) ?></td><td><?= htmlspecialchars($fila['esperado']) ?></td><td><?= htmlspecialchars($fila['obtenido']) ?></td></tr>
<?php endforeach; ?>
  </table>
<?php endforeach; ?>
<?php endif; ?>
</main>
</body>
</html>
