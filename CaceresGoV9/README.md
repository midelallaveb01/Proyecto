CáceresGO · Versión 9

CáceresGO es una aplicación web para descubrir Cáceres a través de rutas. Cada ruta tiene varios lugares de interés; al llegar a cada uno, el visitante escanea su código QR, suma puntos y aparece en la clasificación.

Proyecto de Fin de Grado de 2º de Desarrollo de Aplicaciones Web (DAW).

- Versión publicada: https://caceresgo.infinityfree.io
- Tecnologías: HTML, CSS y JavaScript (sin frameworks), PHP 8 y MySQL.
- Librerías externas: Leaflet 1.9.4 (mapas), mapas de OpenStreetMap, OSRM (caminos a pie por las calles), jsQR 1.4.0 (leer códigos QR con la cámara) y qrcode-generator 1.4.4 (crear códigos QR).

Qué hace la aplicación

Visitantes sin cuenta
- Ver la portada con el mapa de Cáceres y los lugares de interés.
- Ver todas las rutas publicadas con sus lugares, categorías y puntos.
- Ver la clasificación y la actividad de los exploradores (últimos lugares validados).
- Si pulsan Iniciar ruta, se les pide entrar o registrarse; después de hacerlo, la ruta se inicia sola.

Participantes
- Registro, inicio y cierre de sesión. La contraseña se guarda cifrada con password_hash.
- Elegir una ruta activa y cancelarla.
- Mapa de la ruta activa con chinchetas numeradas, el camino real por las calles, la lista de paradas y la posición del usuario en tiempo real. Indica la distancia al siguiente lugar y si se acerca o se aleja.
- Validar lugares con QR: con la cámara del móvil, subiendo una foto o escribiendo la clave. Cada lugar solo se puede validar una vez por cuenta.
- Progreso, puntos, lugares descubiertos y rutas terminadas.
- Perfil y cambio de contraseña.

Clasificación
- Podio con los 3 mejores del mes (últimos 30 días).
- Top 5 de la semana (últimos 7 días).
- Clasificación general con rutas terminadas, lugares y barra de puntos. La fila del usuario conectado aparece destacada.

Administración
- Panel solo para cuentas con el rol admin (el servidor también lo comprueba).
- Gestión de rutas, lugares, categorías, cuentas y resultados.
- Cada categoría fija los puntos de sus lugares, y los puntos de una ruta se calculan con sus lugares.
- Bloquear cuentas: una cuenta bloqueada pierde la sesión abierta. El administrador no puede bloquear su propia cuenta.
- Generar e imprimir los códigos QR de cada lugar.

Actividad de los exploradores
- En la portada aparecen los últimos lugares validados por los participantes. Por privacidad solo se muestra el nombre y la inicial del primer apellido.
- La API responde sin caché, para que siempre se vean los datos actualizados.

Estructura

CaceresGoV9/
├── index.html Estructura de la página, ventanas y paneles
├── css/estilos.css Diseño visual y adaptación a móvil
├── js/caceresGo.js Navegación, mapas, QR, clasificación y llamadas a la API
├── backend/
│ ├── api.php Todas las operaciones (?action=...) y sus validaciones
│ ├── db.php Conexión PDO con MySQL
│ ├── config.example.php Plantilla de configuración (se copia como config.php)
│ ├── crearAdmin.php Crea o cambia la contraseña del administrador desde la terminal
│ └── crearAdmin.ps1 Asistente de PowerShell para lo anterior
├── baseDatos/
│ ├── mysql-schema.sql Base de datos, tablas, 5 rutas, 6 categorías, 21 lugares y administrador
│ └── datos-demo.sql 15 participantes de demostración con visitas y rutas terminadas
└── pruebas/index.php 52 pruebas automáticas de la API (solo funciona en localhost)

Tablas de la base de datos
users, categories, routes, places, routeplaces, visits y routecompletions. Todas en utf8mb4 para que los acentos y la ñ se guarden bien.

Cómo ejecutarla con Xampp

1. Inicia Apache y MySQL desde el panel de Xampp.
2. Copia la carpeta CaceresGoV9 dentro de C:\xampp\htdocs.
3. En phpMyAdmin, sin seleccionar ninguna base, importa baseDatos/mysql-schema.sql. Crea la base caceresgo_v8 con las tablas, las rutas, las categorías y los lugares.
4. Con caceresgo_v8 seleccionada, importa baseDatos/datos-demo.sql para tener los 15 participantes de demostración (contraseña de todos: clave1234).
5. Copia backend/config.example.php como backend/config.php y pon tus datos de MySQL.
6. Abre http://localhost/CaceresGoV9/.

La base de datos se sigue llamando caceresgo_v8 porque la estructura no ha cambiado desde la versión 8, así no hay que volver a instalarla.

No abras index.html con doble clic: la API necesita ejecutarse desde Apache. Antes de apagar el ordenador, pulsa Stop en MySQL para que las tablas no se dañen.

Pruebas automáticas
Con Xampp en marcha, abre http://localhost/CaceresGoV9/pruebas/. Comprueba registro, sesiones, rutas, validación de QR, clasificación, permisos del administrador, etc. Solo funciona desde el propio ordenador y no se sube al hosting.

Datos de prueba
Claves QR de ejemplo: ESTRELLA24, PLAZA24, CASASOL24.

Cuenta de administración
La cuenta carolina@aytocaceres.com se crea al importar mysql-schema.sql. No se puede crear desde el registro: el servidor rechaza los correos @aytocaceres.com y todas las cuentas registradas son de participante. Para cambiar su contraseña, abre PowerShell en la carpeta del proyecto y ejecuta:

.\backend\crearAdmin.ps1

Publicación en InfinityFree

- Los archivos van dentro de htdocs, con la misma estructura de carpetas (sin la carpeta pruebas).
- En el hosting, backend/config.php lleva los datos de MySQL que da InfinityFree. Ese archivo no se sube a GitHub (está en.gitignore).
- La página se abre siempre con https://, necesario para usar la ubicación y la cámara.

Seguridad
- Contraseñas cifradas con passwordhash y comprobadas con passwordverify.
- Consultas con PDO y parámetros preparados para evitar inyección SQL.
- Sesiones de PHP; en cada petición se comprueba en MySQL que la cuenta sigue activa.
- Los textos que escriben los usuarios se escapan antes de mostrarlos.
- Las claves de los QR no se envían en los datos públicos de las rutas.

Historial de versiones

| Versión | Cambios principales |
|---|---|
| V5 | Aplicación conectada a MySQL con PHP (antes usaba Supabase). Registro, rutas, validación por clave QR, progreso, clasificación y panel de administración. Limpieza de archivos duplicados, comentarios por secciones y mensajes claros cuando falla la ubicación. |
| V6 | Una cuenta bloqueada pierde la sesión. El administrador no puede bloquearse a sí mismo. Categorías de lugares que fijan los puntos. Lugares visibles en cada ruta. Dos rutas nuevas y más lugares de Cáceres. Mapa con Leaflet. |
| V7 | Script único para poner al día la base de datos. Página de pruebas automáticas. Tablas en utf8mb4. Mapa de la ruta activa con seguimiento en tiempo real, chinchetas, camino por las calles y lista de paradas. Códigos QR: generarlos, imprimirlos y leerlos con la cámara. |
| V8 | 15 participantes de demostración. Podio del mes (con avatares), top 5 de la semana y clasificación general con iniciales y barra de puntos. Ranking a todo el ancho en el ordenador. Instalación limpia en caceresgo_v8. Actividad de los exploradores en la portada. Siempre con https. Los invitados ven rutas y ranking, pero tienen que entrar para iniciar una ruta. |
| V9 | Se quitan las líneas que aparecían entre los cuadros del mapa cuando el navegador no está al 100 % de zoom. Código limpio y comentado por secciones, datos de demostración renombrados a datos-demo.sql,.gitignore para no subir config.php y este Readme con todo lo hecho. |

Pendiente
- Actualizar el manual técnico y el manual de usuario a esta versión.
- Preparar la presentación de la defensa.
- Revisar en el móvil, con el hosting, el permiso de ubicación.