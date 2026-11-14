# CáceresGO

Aplicación web para descubrir Cáceres haciendo rutas. Cada ruta tiene varios lugares de interés; al llegar a cada uno, se escanea su código QR (o se escribe su clave), se suman puntos y se aparece en la clasificación. El Ayuntamiento, como administrador, gestiona las rutas, los lugares, las categorías y las cuentas desde un panel.

Proyecto Final de Ciclo de **Carolina Rodríguez Muriel**, 2.º de Desarrollo de Aplicaciones Web.

- **Tecnologías:** HTML, CSS y JavaScript (sin frameworks), PHP 8 y MySQL.
- **Librerías:** Leaflet (mapas, con el mapa de OpenStreetMap), jsQR (leer QR con la cámara) y qrcode-generator (crear los QR). Se cargan desde internet, así que hace falta conexión.
- **Versión publicada:** https://caceresgo.infinityfree.io

---

## 1. Cómo probarla en XAMPP

1. Abrir el panel de **XAMPP** y pulsar **Start** en **Apache** y **MySQL**.
2. Copiar esta carpeta dentro de `C:\xampp\htdocs` con el nombre **`CaceresGoV9`** (tiene que quedar `C:\xampp\htdocs\CaceresGoV9\index.html`).
3. Abrir **phpMyAdmin** (`http://localhost/phpmyadmin`). La forma más rápida es, sin seleccionar ninguna base de datos, ir a **Importar** y subir `baseDatos/caceresgoCompleta.sql`, que lo hace todo de una vez. También se puede hacer en dos pasos:
   1. **Sin seleccionar ninguna base de datos**, ir a **Importar** y subir `baseDatos/mysql-schema.sql`. Crea la base de datos **`caceresgo`** con sus tablas, 5 rutas, 6 categorías, 21 lugares y la cuenta del administrador.
   2. Pulsar en **`caceresgo`** (a la izquierda), ir a **Importar** y subir `baseDatos/datos-demo.sql`. Añade 15 participantes de prueba con sus visitas, para que la clasificación tenga datos.
4. Abrir **`http://localhost/CaceresGoV9/`**.

No hace falta crear `backend/config.php`: si no existe, la aplicación usa `backend/config.example.php`, que ya trae los datos normales de XAMPP (usuario `root`, sin contraseña, base `caceresgo`). Si el MySQL tiene otro usuario o contraseña, se copia `config.example.php` como `config.php` y se cambian ahí.

Si algo falla al conectar, la página dice el motivo debajo de las rutas (por ejemplo, que MySQL no está encendido o que la base de datos no existe).

> No hay que abrir `index.html` con doble clic: tiene que abrirse desde `http://localhost/...` para que funcione PHP.

## 2. Cuentas para probar

| Cuenta | Correo | Contraseña |
|---|---|---|
| Administrador | `carolina@aytocaceres.com` | La indico en el manual de uso que entrego aparte (o se puede poner una nueva, apartado 3.3) |
| Participantes de prueba (15) | por ejemplo `luciafdezgomez@hotmail.com` | `clave1234` |

También se puede crear una cuenta nueva de participante con **Entrar / Registrarse → Crear cuenta**.

**Claves de los QR para probar sin estar en Cáceres** (se escriben en la ventana "Valida tu hallazgo"):

| Ruta | Claves de sus lugares |
|---|---|
| Secretos de la Ciudad Monumental | `ESTRELLA24`, `PLAZA24`, `SANTAMARIA24`, `GOLFINES24`, `SANMATEO24` |
| Cáceres de leyenda | `CASASOL24`, `CARVAJAL24`, `SANANTONIO24`, `MOCTEZUMA24` |
| Pequeños exploradores | `SANJORGE24`, `MUSEOCC24`, `ERMITAPAZ24` |
| Torres y murallas | `BUJACO24`, `CIGUENAS24`, `ARCOCRISTO24`, `TORREPOZOS24` |
| Cáceres fuera de la muralla | `SANTIAGO24`, `GODOY24`, `HELGA24`, `PINTORES24`, `MONTANA24` |

Para probar el mapa de la ruta con la ubicación y la cámara hace falta permitirlas en el navegador. En `localhost` funcionan; en internet solo con `https://`.

## 3. La cuenta del administrador

### 3.1. Cómo se crea

La cuenta del Ayuntamiento (`carolina@aytocaceres.com`) **no se crea desde la página**: viene creada en `baseDatos/mysql-schema.sql`, con la contraseña ya cifrada y el rol `admin`:

```sql
INSERT INTO users (name, email, password_hash, role, status)
VALUES ('Carolina Rodríguez Muriel', 'carolina@aytocaceres.com', '$2y$10$...', 'admin', 'active')
ON DUPLICATE KEY UPDATE role = 'admin', status = 'active', password_hash = VALUES(password_hash);
```

Para entrar como administrador se usa la misma ventana que todos (**Entrar / Registrarse → Iniciar sesión**). Si la cuenta tiene el rol `admin`, se abre el **Panel de administración** y aparece el enlace **Panel admin** en la cabecera.

### 3.2. Por qué un usuario normal no se puede registrar como administrador

1. **El registro nunca envía el rol.** El `INSERT` del registro solo guarda nombre, correo y contraseña, y en la tabla `users` el rol tiene `DEFAULT 'participant'`. Aunque alguien modificara la petición desde el navegador, no puede elegir ser `admin`.

   ```php
   $consulta = $baseDatos->prepare('INSERT INTO users (name, email, password_hash) VALUES (?, ?, ?)');
   ```

2. **Los correos del Ayuntamiento están bloqueados en el registro.** Nadie puede registrarse con un correo `@aytocaceres.com`:

   ```php
   // Las cuentas del Ayuntamiento no se pueden crear desde el registro público.
   if (str_ends_with($correo, '@aytocaceres.com')) {
       responder(['error' => 'Este correo no se puede registrar desde aquí'], 403);
   }
   ```

3. **El servidor comprueba el rol en cada acción del panel.** Aunque alguien intentara abrir el panel desde el navegador, todas las acciones de administración empiezan con `exigirAdministrador()`, que responde con un error 403 si la cuenta no es `admin`:

   ```php
   function exigirAdministrador(): array {
       $usuario = exigirUsuario();
       if ($usuario['role'] !== 'admin') responder(['error' => 'No tienes permisos de administrador'], 403);
       return $usuario;
   }
   ```

4. **Una cuenta bloqueada pierde la sesión al momento**, porque en cada petición compruebo en MySQL que sigue activa. Y el administrador no puede bloquear su propia cuenta.

### 3.3. Cómo cambiar la contraseña del administrador (o crear otro)

Con `backend/crearAdmin.php`, que **solo se puede ejecutar desde la terminal** (si se abre desde el navegador devuelve un error 404). En la carpeta del proyecto:

```
C:\xampp\php\php.exe backend\crearAdmin.php
```

Pregunta el correo (si se deja vacío, usa `carolina@aytocaceres.com`) y la contraseña nueva (mínimo 6 caracteres). Si el correo ya existe, le cambia la contraseña; si no, crea una cuenta de administrador nueva.

## 4. Qué se puede hacer

**Sin cuenta:** ver el mapa con los 21 lugares, las rutas con sus lugares y puntos, la clasificación (podio del mes, top 5 de la semana y general) y la actividad de los exploradores.

**Participante:** todo lo anterior y además iniciar una ruta, ver el mapa de la ruta con su posición y la distancia a la siguiente parada, validar lugares (cámara, foto o clave), ver su progreso y cambiar su perfil y su contraseña. Cada lugar solo se puede validar una vez por cuenta.

**Administrador:** crear, editar y borrar rutas y lugares; gestionar categorías (los puntos de un lugar son los de su categoría); imprimir los QR de cada ruta; bloquear y desbloquear cuentas; y ver las rutas terminadas.

## 5. Página de pruebas

Con XAMPP encendido, abrir `http://localhost/CaceresGoV9/pruebas/`, escribir la contraseña del administrador y pulsar **Ejecutar las pruebas**. Comprueba 52 casos de la API (registro, inicio de sesión, validación de QR, permisos del administrador, bloqueo de cuentas, clasificación...). Crea sus propios datos de prueba y los borra al terminar. Solo funciona desde el propio ordenador.

## 6. Estructura

```
CaceresGoV9/
├── index.html               Estructura de la página
├── css/estilos.css          Diseño y versión para el móvil
├── js/caceresGo.js          Lógica de la página (mapa, rutas, QR, clasificación, panel...)
├── backend/
│   ├── api.php              Todas las acciones (?action=...) y sus comprobaciones
│   ├── db.php               Conexión con MySQL (PDO)
│   ├── config.example.php   Datos de conexión de XAMPP
│   └── crearAdmin.php       Crear o cambiar la contraseña del administrador (terminal)
├── baseDatos/
│   ├── mysql-schema.sql     Base de datos caceresgo, tablas, rutas, lugares y administrador
│   ├── datos-demo.sql       15 participantes de prueba
│   └── caceresgoCompleta.sql    Las dos cosas anteriores en un solo archivo
└── pruebas/index.php        Pruebas automáticas de la API
```

**Tablas:** `users` (cuentas, rol y estado), `categories` (categorías y puntos), `routes` (rutas), `places` (lugares, clave QR, coordenadas), `visits` (lugares validados) y `route_completions` (rutas terminadas).

## 7. Partes importantes del código

**Contraseñas cifradas.** Nunca se guarda la contraseña: se guarda su hash con `password_hash` y al entrar se comprueba con `password_verify`.

**Consultas preparadas.** Todas las consultas con datos del usuario usan `prepare` y `?`, para evitar la inyección SQL.

**No se puede validar dos veces el mismo lugar.** La tabla `visits` tiene una clave única `(user_id, place_id)`. Si se intenta repetir, MySQL da el error 1062 y respondo con un 409:

```php
} catch (PDOException $error) {
    if ($error->errorInfo[1] === 1062) responder(['error' => 'Ya habías validado este lugar'], 409);
    throw $error;
}
```

**Una sola función para hablar con el servidor.** En JavaScript, todas las peticiones pasan por `solicitarAPI(accion, opciones)`, que hace el `fetch` a `backend/api.php?action=...` y devuelve el JSON.

**El QR lleva un enlace con la clave** (`?clave=PLAZA24`). Si se escanea con la cámara normal del móvil y hay sesión iniciada, la página valida el lugar sola al abrirse.

**Las secciones de la página** se cambian poniendo una clase en el `body` (`home-view`, `route-view`, `progress-view`...) desde la función `mostrarPagina()`.

## 8. Lo que he aprendido

- A pasar de guardar todo en `localStorage` (mis primeras versiones) a tener un servidor propio con PHP y una base de datos MySQL compartida por todos los usuarios.
- A hacer una API en PHP que responde en JSON y a llamarla desde JavaScript con `fetch` y `async`/`await`.
- A guardar contraseñas de forma segura y a proteger las partes de administración en el servidor, no solo escondiendo botones en la página.
- A diseñar las tablas con claves foráneas y claves únicas para que la propia base de datos impida errores como validar dos veces un lugar.
- A usar librerías externas (Leaflet para el mapa, jsQR para la cámara) leyendo su documentación.
- A usar la ubicación y la cámara del navegador, y que solo funcionan con `https://` o en `localhost`.
- A publicar en un hosting (InfinityFree): subir los archivos, crear la base de datos y separar los datos de conexión en `config.php`, distinto en mi ordenador y en el hosting.
- A probar: con una página de pruebas automáticas y probando en el ordenador y en el móvil.
- A resolver problemas reales: MySQL de XAMPP que se cerraba de golpe, el navegador que guardaba archivos antiguos, o la conexión con la base de datos del hosting.

## 9. Uso de herramientas de IA

He usado herramientas de inteligencia artificial como apoyo durante el proyecto (revisar código, encontrar errores, proponer soluciones y ayudar a redactar la documentación), con conocimiento de mi tutora. He revisado, probado y adaptado el código a mi nivel.

## 10. Mejoras futuras

- Que el QR de cada lugar lleve también a una pista de la siguiente parada.
- Recuperar la contraseña por correo.
- Insignias o sellos por completar rutas.
