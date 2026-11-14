// 1. Mapa, ubicación y comunicación con el servidor
// En internet la página tiene que ir por https: sin eso el navegador no deja usar la ubicación ni la cámara.
if (window.location.protocol === "http:" && !["localhost", "127.0.0.1"].includes(window.location.hostname)) {
    window.location.replace(`https:${window.location.href.slice(5)}`);
}
const elementoMapa = document.querySelector("#location-map");
const botonUbicacion = document.querySelector("#locate-me");
const estadoUbicacion = document.querySelector("#location-status");
const urlAPI = "backend/api.php";

let usuarioActual = null;
let rutasEnCache = [];
let lugaresEnCache = [];
let categoriasEnCache = [];
let idRutaSeleccionada = null;
let mapa = null;
let capaLugares = null;
let marcadorUsuario = null;

// Hago una petición a la API y devuelvo su respuesta en JSON.
async function solicitarAPI(accion, opciones = {}) {
    if (window.location.protocol === "file:") {
        throw new Error("Abre la aplicación desde Apache/XAMPP en una dirección http://localhost, no como archivo.");
    }

    const url = new URL(urlAPI, window.location.href);
    url.searchParams.set("action", accion);
    if (opciones.parametros) {
        Object.entries(opciones.parametros).forEach(([clave, valor]) => {
            if (valor !== null && valor !== undefined) url.searchParams.set(clave, valor);
        });
    }

    let respuesta;
    try {
        // Espero a que el servidor responda a la petición.
        respuesta = await fetch(url, {
            method: opciones.metodo || "GET",
            credentials: "same-origin",
            cache: "no-store",
            headers: opciones.datos ? { "Content-Type": "application/json" } : {},
            body: opciones.datos ? JSON.stringify(opciones.datos) : undefined
        });
    } catch (error) {
        if (error instanceof TypeError) {
            throw new Error("No se puede conectar con el servidor. Inicia Apache y MySQL en XAMPP y abre la aplicación desde localhost.");
        }
        throw error;
    }

    let resultado;
    try {
        // Espero a que llegue la respuesta completa para leer su JSON.
        resultado = await respuesta.json();
    } catch {
        throw new Error("El servidor no ejecuta PHP o no está configurado. Abre la aplicación desde Apache/XAMPP y revisa backend/config.php.");
    }
    if (!respuesta.ok) {
        const error = new Error(resultado.error || "No se pudo completar la operación.");
        error.estado = respuesta.status;
        throw error;
    }
    return resultado;
}

// Muestro en un elemento el mensaje de error del servidor o uno por defecto.
function mostrarError(elemento, error, mensajeAlternativo) {
    elemento.textContent = error.message || mensajeAlternativo;
}

// Cambio el texto y el color del aviso de ubicación del mapa.
function actualizarEstadoUbicacion(mensaje, tipo = "") {
    estadoUbicacion.textContent = mensaje;
    estadoUbicacion.className = `location-status ${tipo}`.trim();
}
// Creo el mapa con Leaflet. Si la librería no ha cargado (sin internet), uso el mapa sencillo de OpenStreetMap.
function crearMapa() {
    if (!window.L) {
        mostrarMapa(39.4745, -6.3705);
        return;
    }
    mapa = L.map(elementoMapa).setView([39.4745, -6.3705], 16);
    capaCalles().addTo(mapa);
    capaLugares = L.layerGroup().addTo(mapa);
}

// Pongo en el mapa un punto por cada lugar de interés, con su categoría, sus puntos y su ruta.
function pintarLugaresEnMapa(rutas) {
    if (!mapa) return;
    capaLugares.clearLayers();
    rutas.forEach((ruta) => (ruta.places || []).forEach((lugar) => {
        if (lugar.latitude === null || lugar.longitude === null) return;
        L.circleMarker([Number(lugar.latitude), Number(lugar.longitude)], {
            radius: 8, color: "#102b2a", weight: 2, fillColor: "#ee6b54", fillOpacity: 0.9
        }).bindPopup(`<strong>${escaparTexto(lugar.name)}</strong><br>${escaparTexto(lugar.category_name || "Sin categoría")} · ${lugar.points} pts<br><small>${escaparTexto(ruta.name)}</small>`)
            .addTo(capaLugares);
    }));
}

// Muestro el mapa de OpenStreetMap centrado en unas coordenadas.
function mostrarMapa(latitud, longitud) {
    const margen = 0.008;
    const limites = [
        longitud - margen,
        latitud - margen,
        longitud + margen,
        latitud + margen
    ].map((coordenada) => coordenada.toFixed(6)).join("%2C");
    const urlMapa = `https://www.openstreetmap.org/export/embed.html?bbox=${limites}&layer=mapnik&marker=${latitud}%2C${longitud}`;
    elementoMapa.innerHTML = `<iframe title="Mapa de tu ubicación" loading="eager" src="${urlMapa}"></iframe>`;
}

// Cuando el navegador da la posición, pongo al usuario en el mapa.
function mostrarUbicacion({ coords: coordenadas }) {
    const { latitude: latitud, longitude: longitud } = coordenadas;
    if (mapa) {
        // Marco dónde está el usuario y centro el mapa en su posición.
        if (marcadorUsuario) marcadorUsuario.remove();
        marcadorUsuario = L.circleMarker([latitud, longitud], {
            radius: 9, color: "#ffffff", weight: 3, fillColor: "#174842", fillOpacity: 1
        }).bindPopup("Estás aquí").addTo(mapa);
        mapa.setView([latitud, longitud], 16);
    } else {
        mostrarMapa(latitud, longitud);
    }
    actualizarEstadoUbicacion(`Ubicación encontrada: ${latitud.toFixed(5)}, ${longitud.toFixed(5)}`, "correcto");
    botonUbicacion.disabled = false;
}

const mensajesFalloUbicacion = {
    1: "La ubicación está bloqueada para esta página. Pulsa el candado de la barra de direcciones y permítela.",
    2: "El equipo no encuentra tu posición. Comprueba que la ubicación está activada en el sistema.",
    3: "La ubicación está tardando demasiado. Inténtalo de nuevo."
};

// Explico al usuario por qué no se ha podido obtener su ubicación.
function mostrarFalloUbicacion(fallo) {
    actualizarEstadoUbicacion(mensajesFalloUbicacion[fallo.code] || "No hemos podido obtener tu ubicación. Inténtalo de nuevo.", "error");
    botonUbicacion.disabled = false;
}

// Pido la ubicación al navegador al pulsar "Usar mi ubicación".
function localizarUsuario() {
    if (!navigator.geolocation) {
        actualizarEstadoUbicacion("Tu navegador no permite obtener la ubicación.", "error");
        return;
    }

    // El navegador solo da la ubicación en https:// o en localhost.
    if (!window.isSecureContext) {
        actualizarEstadoUbicacion("La ubicación solo funciona con https:// o desde localhost.", "error");
        return;
    }

    botonUbicacion.disabled = true;
    actualizarEstadoUbicacion("Permitir ubicación a la página para mostrar tu posición...");
    navigator.geolocation.getCurrentPosition(mostrarUbicacion, (fallo) => {
        // Un ordenador no tiene GPS: si tarda demasiado, lo intento con la ubicación aproximada por wifi.
        if (fallo.code === 3) {
            navigator.geolocation.getCurrentPosition(mostrarUbicacion, mostrarFalloUbicacion, { enableHighAccuracy: false, timeout: 15000, maximumAge: 60000 });
            return;
        }
        mostrarFalloUbicacion(fallo);
    }, { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 });
}

// Botón del mapa para buscar al usuario.
botonUbicacion?.addEventListener("click", localizarUsuario);

// 2. Ventanas y lectura de códigos QR
document.querySelectorAll("[data-open]").forEach((boton) => {
    boton.addEventListener("click", () => document.querySelector("#modal").classList.add("open"));
});

// Todos los botones con data-close cierran su ventana.
document.querySelectorAll("[data-close]").forEach((boton) => {
    boton.addEventListener("click", () => {
        boton.closest(".modal").classList.remove("open");
        detenerCamara();
    });
});

const tarjetaProgreso = document.querySelector(".progress-card");
const botonLeerRuta = document.createElement("button");
botonLeerRuta.className = "primary scan-route-button";
botonLeerRuta.type = "button";
botonLeerRuta.textContent = "Leer QR de una ruta";
tarjetaProgreso?.append(botonLeerRuta);

const ventanaRuta = document.querySelector("#modal");
const tituloVentanaRuta = document.querySelector("#modal-title");
const claveRuta = document.querySelector("#code");
const botonValidarRuta = document.querySelector("#validate");
const cuadroRuta = ventanaRuta?.querySelector(".dialog");
const mensajeRuta = document.createElement("p");
const selectorImagenQr = document.createElement("input");
mensajeRuta.className = "route-message";
selectorImagenQr.type = "file";
selectorImagenQr.accept = "image/*";
selectorImagenQr.capture = "environment";
selectorImagenQr.hidden = true;
cuadroRuta?.append(mensajeRuta, selectorImagenQr);

const cajaCamara = document.querySelector("#camera-box");
const videoCamara = document.querySelector("#camera-video");
const dibujoQr = ventanaRuta?.querySelector(".qr");
const lienzoLector = document.createElement("canvas");
let flujoCamara = null;
let ultimaLectura = 0;

// Saco la clave del texto del QR: puede ser la clave sola o un enlace con ?clave=.
function extraerClave(texto) {
    try {
        return (new URL(texto).searchParams.get("clave") || "").trim().toUpperCase();
    } catch {
        return texto.trim().toUpperCase();
    }
}

// Busco un QR en una imagen o en el vídeo de la cámara con jsQR, que funciona en todos los navegadores.
function leerQrDeImagen(origen, ancho, alto) {
    lienzoLector.width = ancho;
    lienzoLector.height = alto;
    const contexto = lienzoLector.getContext("2d", { willReadFrequently: true });
    contexto.drawImage(origen, 0, 0, ancho, alto);
    const codigo = jsQR(contexto.getImageData(0, 0, ancho, alto).data, ancho, alto);
    return codigo ? codigo.data : null;
}

// Enciendo la cámara trasera del móvil para leer el QR.
async function iniciarCamara() {
    if (!window.jsQR) {
        mensajeRuta.textContent = "No se ha podido cargar el lector de QR. Escribe la clave debajo.";
        return;
    }
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
        mensajeRuta.textContent = "La cámara solo funciona con https:// o desde localhost. Elige una foto o escribe la clave.";
        return;
    }
    try {
        // Espero a que el usuario dé permiso para usar la cámara trasera.
        flujoCamara = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false });
        videoCamara.srcObject = flujoCamara;
        // Espero a que el vídeo empiece a verse.
        await videoCamara.play();
        cajaCamara.hidden = false;
        dibujoQr.hidden = true;
        mensajeRuta.textContent = "Apunta la cámara al código QR del lugar.";
        window.requestAnimationFrame(buscarQrEnVideo);
    } catch {
        detenerCamara();
        mensajeRuta.textContent = "No se ha podido abrir la cámara. Elige una foto o escribe la clave.";
    }
}

// Miro el vídeo de la cámara hasta que encuentro un QR.
function buscarQrEnVideo(momento) {
    if (!flujoCamara) return;
    // Analizo unas cinco imágenes por segundo para no gastar batería.
    if (momento - ultimaLectura > 200 && videoCamara.readyState >= 2 && videoCamara.videoWidth) {
        ultimaLectura = momento;
        const escala = Math.min(1, 640 / videoCamara.videoWidth);
        const texto = leerQrDeImagen(videoCamara, Math.round(videoCamara.videoWidth * escala), Math.round(videoCamara.videoHeight * escala));
        if (texto) {
            detenerCamara();
            claveRuta.value = extraerClave(texto);
            botonValidarRuta.click();
            return;
        }
    }
    window.requestAnimationFrame(buscarQrEnVideo);
}

// Apago la cámara al cerrar la ventana o al encontrar el QR.
function detenerCamara() {
    flujoCamara?.getTracks().forEach((pista) => pista.stop());
    flujoCamara = null;
    if (videoCamara) videoCamara.srcObject = null;
    if (cajaCamara) cajaCamara.hidden = true;
    if (dibujoQr) dibujoQr.hidden = false;
}

// Abre la ventana para leer el QR del lugar.
botonLeerRuta.addEventListener("click", () => {
    tituloVentanaRuta.textContent = "Lee el QR de tu ruta";
    mensajeRuta.textContent = "";
    ventanaRuta.classList.add("open");
    iniciarCamara();
});

// Botones para leer el QR con la cámara o desde una foto.
document.querySelector("#camera-start")?.addEventListener("click", iniciarCamara);
document.querySelector("#photo-pick")?.addEventListener("click", () => {
    detenerCamara();
    selectorImagenQr.click();
});

// Cuando se elige una foto, busco el QR dentro de ella.
selectorImagenQr.addEventListener("change", async () => {
    const archivoImagen = selectorImagenQr.files[0];
    if (!archivoImagen) return;
    if (!window.jsQR || !window.createImageBitmap) {
        mensajeRuta.textContent = "Tu navegador no puede leer la imagen automáticamente. Escribe la clave debajo.";
        return;
    }
    try {
        // Espero a que el navegador convierta la foto en una imagen que pueda analizar.
        const imagen = await createImageBitmap(archivoImagen);
        const escala = Math.min(1, 1200 / Math.max(imagen.width, imagen.height));
        const texto = leerQrDeImagen(imagen, Math.round(imagen.width * escala), Math.round(imagen.height * escala));
        if (texto) {
            claveRuta.value = extraerClave(texto);
            mensajeRuta.textContent = "QR leído correctamente. Pulsa Validar visita.";
        } else {
            mensajeRuta.textContent = "No se ha encontrado ningún QR en la imagen.";
        }
    } catch {
        mensajeRuta.textContent = "No se ha podido leer el QR. Prueba con otra imagen.";
    }
    selectorImagenQr.value = "";
});

// Envío la clave al servidor para validar el lugar y sumar los puntos.
botonValidarRuta.addEventListener("click", async () => {
    const codigo = claveRuta.value.trim().toUpperCase();
    if (!codigo) {
        mensajeRuta.textContent = "Escribe una clave o selecciona una imagen con un QR.";
        return;
    }
    if (!usuarioActual) {
        mensajeRuta.textContent = "Inicia sesión para poder validar visitas.";
        return;
    }

    botonValidarRuta.disabled = true;
    mensajeRuta.textContent = "Comprobando código...";
    try {
        // Espero a que el servidor valide el código QR.
        const { place: lugar } = await solicitarAPI("validate-visit", {
            metodo: "POST",
            datos: { qr_code: codigo }
        });
        mensajeRuta.textContent = `"${lugar.name}" validado. Has conseguido ${lugar.points} puntos.`;
        // Actualizo el progreso antes de continuar.
        await actualizarProgresoUsuario();
        // Espero a que se refresque la clasificación.
        await cargarClasificacion();
        // Espero a que se actualicen las estadísticas.
        await cargarEstadisticasPublicas();
        // Espero a que mi visita aparezca en la actividad de los exploradores.
        await cargarActividad();
        claveRuta.value = "";
    } catch (error) {
        // Si el servidor ya no reconoce la sesión (por ejemplo, la cuenta se ha bloqueado), la cierro también en pantalla.
        if (error.estado === 401) limpiarUsuarioConectado();
        mensajeRuta.textContent = error.estado === 409
            ? "Ya habías validado este lugar antes."
            : error.estado === 401
                ? "Tu sesión ha terminado. Vuelve a iniciar sesión para validar visitas."
                : error.message;
    } finally {
        botonValidarRuta.disabled = false;
    }
});

// 3. Rutas disponibles y ruta activa
const contenidoRutas = document.querySelector("#routes-content");
const mensajeRutaActiva = document.createElement("p");
mensajeRutaActiva.className = "active-route-message";
const controlesRutaActiva = document.createElement("div");
controlesRutaActiva.className = "active-route-controls";
const botonVerRutaActiva = document.createElement("button");
botonVerRutaActiva.className = "primary";
botonVerRutaActiva.type = "button";
botonVerRutaActiva.textContent = "Ver ruta activa";
botonVerRutaActiva.hidden = true;
const botonCancelarRutaActiva = document.createElement("button");
botonCancelarRutaActiva.className = "cancel-active-route";
botonCancelarRutaActiva.type = "button";
botonCancelarRutaActiva.textContent = "Cancelar ruta";
botonCancelarRutaActiva.hidden = true;
controlesRutaActiva.append(botonVerRutaActiva, botonCancelarRutaActiva);
mensajeRutaActiva.textContent = "No tienes una ruta activa. Elige una ruta para empezar.";
tarjetaProgreso?.append(mensajeRutaActiva, controlesRutaActiva);

// Guardo la ruta elegida como ruta activa y la marco en su tarjeta.
function marcarRutaActiva(ruta) {
    localStorage.setItem("caceresgo-ruta-activa", ruta.name);
    localStorage.setItem("caceresgo-ruta-activa-id", ruta.id);
    mensajeRutaActiva.textContent = `Ruta en curso: ${ruta.name}`;
    botonVerRutaActiva.hidden = false;
    botonCancelarRutaActiva.hidden = false;
    document.querySelectorAll(".route").forEach((tarjeta) => {
        const botonIniciarRuta = tarjeta.querySelector(".start-route-button");
        const botonCancelarRuta = tarjeta.querySelector(".cancel-route-button");
        const estaActiva = tarjeta.dataset.routeId === String(ruta.id);
        tarjeta.classList.toggle("active-route", estaActiva);
        if (botonIniciarRuta) botonIniciarRuta.textContent = estaActiva ? "Ruta en curso" : "Iniciar ruta";
        if (botonCancelarRuta) botonCancelarRuta.hidden = !estaActiva;
    });
}

// Quito la ruta activa del navegador y de las tarjetas.
function limpiarRutaActiva() {
    localStorage.removeItem("caceresgo-ruta-activa");
    localStorage.removeItem("caceresgo-ruta-activa-id");
    mensajeRutaActiva.textContent = "No tienes una ruta activa. Elige una ruta para empezar.";
    botonVerRutaActiva.hidden = true;
    botonCancelarRutaActiva.hidden = true;
    document.querySelectorAll(".route").forEach((tarjeta) => {
        tarjeta.classList.remove("active-route");
        const botonIniciarRuta = tarjeta.querySelector(".start-route-button");
        const botonCancelarRuta = tarjeta.querySelector(".cancel-route-button");
        if (botonIniciarRuta) botonIniciarRuta.textContent = "Iniciar ruta";
        if (botonCancelarRuta) botonCancelarRuta.hidden = true;
    });
}

// Lleva a la tarjeta de la ruta activa.
botonVerRutaActiva.addEventListener("click", () => {
    const idRutaActiva = localStorage.getItem("caceresgo-ruta-activa-id");
    const tarjetaActiva = Array.from(document.querySelectorAll(".route"))
        .find((tarjeta) => tarjeta.dataset.routeId === idRutaActiva);
    if (!tarjetaActiva) {
        limpiarRutaActiva();
        mensajeRutaActiva.textContent = "La ruta guardada ya no está disponible. Elige otra ruta para continuar.";
        return;
    }
    mostrarPagina("route");
    window.requestAnimationFrame(() => tarjetaActiva.scrollIntoView({ behavior: "smooth", block: "center" }));
});

// Cancelo la ruta activa y actualizo el progreso.
async function cancelarRutaActiva() {
    limpiarRutaActiva();
    // Actualizo el progreso después de quitar la ruta activa.
    await actualizarProgresoUsuario();
}

// Botón para cancelar la ruta activa.
botonCancelarRutaActiva.addEventListener("click", cancelarRutaActiva);

let rutaPendiente = null;

// Añado el botón "Iniciar ruta" a cada tarjeta. Si no hay sesión, se pide entrar y la ruta se inicia después.
function agregarBotonesIniciarRuta() {
    document.querySelectorAll(".route").forEach((tarjeta) => {
        if (tarjeta.querySelector(".start-route-button")) return;
        const botonIniciarRuta = document.createElement("button");
        botonIniciarRuta.className = "start-route-button";
        botonIniciarRuta.type = "button";
        botonIniciarRuta.textContent = "Iniciar ruta";
        tarjeta.append(botonIniciarRuta);
        const botonCancelarRuta = document.createElement("button");
        botonCancelarRuta.className = "cancel-route-button";
        botonCancelarRuta.type = "button";
        botonCancelarRuta.textContent = "Cancelar ruta";
        botonCancelarRuta.hidden = true;
        tarjeta.append(botonCancelarRuta);
        botonIniciarRuta.addEventListener("click", async () => {
            const ruta = {
                id: tarjeta.dataset.routeId,
                name: tarjeta.querySelector("h3").textContent
            };
            // Sin sesión se puede ver la ruta, pero para iniciarla hay que entrar. La guardo para iniciarla después.
            if (!usuarioActual) {
                rutaPendiente = ruta;
                document.querySelector("#auth-modal")?.classList.add("open");
                return;
            }
            marcarRutaActiva(ruta);
            mostrarPagina("progress");
            // Espero a que aparezca el progreso de la ruta que acabo de iniciar.
            await actualizarProgresoUsuario();
        });
        botonCancelarRuta.addEventListener("click", cancelarRutaActiva);
    });
}

// Creo el HTML de la tarjeta de una ruta con sus lugares, categorías y puntos.
function crearTarjetaRutaHTML(ruta, indice) {
    const clasesEstilo = ["large", "sand", "lime"];
    const iconos = ["⌘", "♜", "✹"];
    const claseEstilo = clasesEstilo[indice % clasesEstilo.length];
    const icono = iconos[indice % iconos.length];
    const etiqueta = indice === 0 ? "Más popular" : "Recorrido";
    const lugaresRuta = (ruta.places || []).map((lugar) =>
        `<li><span>${escaparTexto(lugar.name)}</span><small>${escaparTexto(lugar.category_name || "Sin categoría")} · ${lugar.points} pts</small></li>`
    ).join("");
    return `<article class="route ${claseEstilo}" data-route-id="${ruta.id}"><span class="route-tag">${etiqueta}</span><span class="number">${String(indice + 1).padStart(2, "0")}</span><h3>${escaparTexto(ruta.name)}</h3><p>${escaparTexto(ruta.duration || "")} · ${ruta.total_places} ${Number(ruta.total_places) === 1 ? "lugar" : "lugares"} · ${ruta.points} puntos</p>${lugaresRuta ? `<ul class="route-places">${lugaresRuta}</ul>` : ""}<span class="route-icon">${icono}</span></article>`;
}

// Cargo las rutas publicadas y pinto sus tarjetas.
async function cargarRutasPublicas() {
    try {
        // Espero a que el servidor me devuelva las rutas disponibles.
        const { routes: rutas } = await solicitarAPI("routes");
        const etiquetaNumeroRutas = document.querySelector("#route-count");
        if (etiquetaNumeroRutas) etiquetaNumeroRutas.textContent = rutas.length;
        if (!rutas.length) {
            contenidoRutas.innerHTML = '<p class="empty-admin">Todavía no hay recorridos publicados.</p>';
            limpiarRutaActiva();
            return;
        }
        contenidoRutas.innerHTML = rutas.map(crearTarjetaRutaHTML).join("");
        agregarBotonesIniciarRuta();
        pintarLugaresEnMapa(rutas);
        const idRutaGuardada = localStorage.getItem("caceresgo-ruta-activa-id");
        const rutaGuardada = rutas.find((ruta) => String(ruta.id) === idRutaGuardada);
        if (rutaGuardada) {
            marcarRutaActiva(rutaGuardada);
        } else {
            limpiarRutaActiva();
        }
    } catch (error) {
        contenidoRutas.innerHTML = `<p class="empty-admin">${escaparTexto(error.message)}</p>`;
    }
}

// 4. Navegación entre las secciones
document.querySelector("#account-button")?.addEventListener("click", (evento) => {
    evento.preventDefault();
    if (usuarioActual) mostrarPagina("profile");
    else document.querySelector("#auth-modal")?.classList.add("open");
});

// Botones de los avisos que abren la ventana para entrar.
document.querySelector("#wall-login")?.addEventListener("click", () => {
    document.querySelector("#auth-modal")?.classList.add("open");
});
document.querySelector("#routes-login")?.addEventListener("click", () => {
    document.querySelector("#auth-modal")?.classList.add("open");
});

// Muestro la sección pedida cambiando la clase del body.
function mostrarPagina(vista) {
    if (vista === "admin" && usuarioActual?.role !== "admin") {
        vista = "home";
    }
    document.body.classList.remove("home-view", "progress-view", "route-view", "ranking-view", "profile-view", "admin-view");
    document.body.classList.add(`${vista}-view`);
    window.scrollTo({ top: 0, behavior: "smooth" });
    // El seguimiento de la ruta solo está activo mientras se ve "Mi progreso".
    if (vista === "progress") {
        if (mapaRuta) window.requestAnimationFrame(() => mapaRuta.invalidateSize());
        iniciarSeguimiento();
    } else {
        detenerSeguimiento();
    }
}

// Enlaces del menú a cada sección.
document.querySelectorAll('a[href="#progreso"]').forEach((enlace) => {
    enlace.addEventListener("click", (evento) => { evento.preventDefault(); mostrarPagina("progress"); });
});
document.querySelectorAll('a[href="#ranking"]').forEach((enlace) => {
    enlace.addEventListener("click", (evento) => { evento.preventDefault(); mostrarPagina("ranking"); });
});
document.querySelectorAll('a[href="#rutas"]').forEach((enlace) => {
    enlace.addEventListener("click", (evento) => { evento.preventDefault(); mostrarPagina("route"); });
});
document.querySelectorAll('a[href="#inicio"]').forEach((enlace) => {
    enlace.addEventListener("click", (evento) => { evento.preventDefault(); mostrarPagina("home"); });
});

// 5. Registro, inicio de sesión y perfil
const ventanaAcceso = document.querySelector("#auth-modal");
const formularioAcceso = document.querySelector("#auth-form");
const pestanasAcceso = document.querySelectorAll("[data-tab]");
const campoNombre = document.querySelector("#name-field");
const nombreAcceso = document.querySelector("#auth-name");
const correoAcceso = document.querySelector("#auth-email");
const contrasenaAcceso = document.querySelector("#auth-password");
const botonEnviarAcceso = document.querySelector("#auth-submit");
const mensajeFormulario = document.querySelector("#form-message");
const nombreCuenta = document.querySelector("#account-label");
const botonCerrarSesion = document.querySelector("#logout-button");
const nombrePerfil = document.querySelector("#profile-name");
const correoPerfil = document.querySelector("#profile-email");
const nacimientoPerfil = document.querySelector("#profile-birth");
const ciudadPerfil = document.querySelector("#profile-city");
const botonGuardarPerfil = document.querySelector("#save-profile");
const mensajePerfil = document.querySelector("#profile-message");
const formularioContrasena = document.querySelector("#password-form");
const contrasenaActual = document.querySelector("#current-password");
const contrasenaNueva = document.querySelector("#new-password");
const repetirContrasena = document.querySelector("#repeat-password");
const mensajeContrasena = document.querySelector("#password-message");
const botonProgresoPerfil = document.querySelector("#profile-progress");
const avisoAcceso = document.querySelector("#auth-wall");
const contenidoPrivado = document.querySelector("#private-content");
const avisoRutas = document.querySelector("#routes-wall");
let modoAcceso = "inicio";

nombreAcceso?.setAttribute("autocomplete", "name");
correoAcceso?.setAttribute("autocomplete", "username");
contrasenaAcceso?.setAttribute("autocomplete", "current-password");

// Cambio la ventana entre "Iniciar sesión" y "Registrarse".
function cambiarModoAcceso(modo) {
    modoAcceso = modo;
    pestanasAcceso.forEach((pestana) => pestana.classList.toggle("active", pestana.dataset.tab === modo));
    campoNombre.hidden = modo !== "registro";
    nombreAcceso.required = modo === "registro";
    botonEnviarAcceso.textContent = modo === "registro" ? "Crear cuenta" : "Iniciar sesión";
    mensajeFormulario.textContent = "";
}

// Actualizo los datos del usuario conectado en la pantalla.
function actualizarUsuarioConectado(usuario) {
    usuarioActual = usuario;
    document.querySelector("#admin-open").hidden = usuario.role !== "admin";
    document.body.classList.toggle("admin-authenticated", usuario.role === "admin");
    nombreCuenta.textContent = usuario.name;
    nombrePerfil.textContent = usuario.name;
    correoPerfil.textContent = usuario.email;
    nacimientoPerfil.value = usuario.birth_date || "";
    ciudadPerfil.value = usuario.city || "";
    botonCerrarSesion.hidden = false;
    avisoAcceso.classList.add("hidden");
    contenidoPrivado.classList.add("visible");
    avisoRutas.classList.add("hidden");
    contenidoRutas.classList.add("visible");
}

// Quito los datos del usuario al cerrar la sesión.
function limpiarUsuarioConectado() {
    usuarioActual = null;
    document.querySelector("#admin-open").hidden = true;
    document.body.classList.remove("admin-authenticated");
    nombreCuenta.textContent = "Entrar / Registrarse";
    nombrePerfil.textContent = "-";
    correoPerfil.textContent = "-";
    nacimientoPerfil.value = "";
    ciudadPerfil.value = "";
    botonCerrarSesion.hidden = true;
    avisoAcceso.classList.remove("hidden");
    contenidoPrivado.classList.remove("visible");
    avisoRutas.classList.remove("hidden");
    contenidoRutas.classList.remove("visible");
    detenerSeguimiento();
    contenedorSeguimiento.hidden = true;
}

// Desde el perfil se puede ir directamente al progreso.
botonProgresoPerfil?.addEventListener("click", () => mostrarPagina("progress"));

// Guardo los cambios del perfil.
botonGuardarPerfil?.addEventListener("click", async () => {
    if (!usuarioActual) return;
    mensajePerfil.textContent = "Guardando datos...";
    try {
        // Espero a que el servidor guarde los cambios del perfil.
        const { user: usuario } = await solicitarAPI("profile", {
            metodo: "PATCH",
            datos: {
                name: nombrePerfil.textContent.trim(),
                birth_date: nacimientoPerfil.value,
                city: ciudadPerfil.value.trim()
            }
        });
        actualizarUsuarioConectado(usuario);
        mensajePerfil.textContent = "Datos guardados correctamente.";
    } catch (error) {
        mostrarError(mensajePerfil, error, "No se han podido guardar los datos.");
    }
});
// Cambia la contraseña del usuario al enviar el formulario correspondiente
formularioContrasena?.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    if (contrasenaNueva.value !== repetirContrasena.value) {
        mensajeContrasena.textContent = "Las nuevas contraseñas no coinciden.";
        return;
    }
    try {
        // Espero a que el servidor compruebe la contraseña actual y guarde la nueva.
        await solicitarAPI("password", {
            metodo: "POST",
            datos: {
                current_password: contrasenaActual.value,
                new_password: contrasenaNueva.value
            }
        });
        formularioContrasena.reset();
        mensajeContrasena.textContent = "Contraseña cambiada correctamente.";
    } catch (error) {
        mostrarError(mensajeContrasena, error, "No se ha podido cambiar la contraseña.");
    }
});

// Cierro la sesión del participante.
botonCerrarSesion?.addEventListener("click", async () => {
    try {
        // Espero a que el servidor cierre la sesión antes de limpiar la pantalla.
        await solicitarAPI("logout", { metodo: "POST" });
        limpiarUsuarioConectado();
        localStorage.removeItem("caceresgo-ruta-activa");
        localStorage.removeItem("caceresgo-ruta-activa-id");
        mostrarPagina("home");
    } catch (error) {
        mensajePerfil.textContent = `No se ha podido cerrar la sesión: ${error.message}`;
    }
});

// Pestañas de la ventana de acceso.
pestanasAcceso.forEach((pestana) => {
    pestana.addEventListener("click", (evento) => {
        evento.preventDefault();
        formularioAcceso.reset();
        cambiarModoAcceso(pestana.dataset.tab);
    });
});

// Envío el formulario para iniciar sesión o registrarse.
formularioAcceso?.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    const correo = correoAcceso.value.trim().toLowerCase();
    const contrasena = contrasenaAcceso.value;
    // La pestaña usa "inicio"/"registro"; la API espera "login"/"register".
    const accion = modoAcceso === "registro" ? "register" : "login";
    const datos = { email: correo, password: contrasena };
    if (accion === "register") datos.name = nombreAcceso.value.trim();

    botonEnviarAcceso.disabled = true;
    mensajeFormulario.textContent = "Comprobando...";
    try {
        // Espero a que el servidor termine el inicio de sesión o el registro.
        const { user: usuario } = await solicitarAPI(accion, { metodo: "POST", datos });
        actualizarUsuarioConectado(usuario);
        ventanaAcceso.classList.remove("open");
        formularioAcceso.reset();
        cambiarModoAcceso("inicio");
        if (usuario.role === "admin") {
            await abrirPanelAdministrador();
        } else {
            // Si había pulsado "Iniciar ruta" antes de entrar, la inicio ahora.
            if (rutaPendiente) {
                marcarRutaActiva(rutaPendiente);
                rutaPendiente = null;
                mostrarPagina("progress");
            }
            // Cargo el progreso del usuario después de iniciar sesión.
            await actualizarProgresoUsuario();
        }
        // Refresco la clasificación con la sesión ya iniciada.
        await cargarClasificacion();
    } catch (error) {
        mostrarError(mensajeFormulario, error, "No se ha podido iniciar sesión.");
    } finally {
        botonEnviarAcceso.disabled = false;
    }
});

// Al abrir la página, compruebo si ya había una sesión iniciada.
async function restaurarSesion() {
    try {
        // Consulto al servidor para saber si ya había una sesión iniciada.
        const { user: usuario } = await solicitarAPI("me");
        if (usuario) actualizarUsuarioConectado(usuario);
    } catch (error) {
        console.error("No se pudo recuperar la sesión:", error);
    }
}

// 6. Progreso del participante
// Pinto los puntos, los lugares y el progreso de la ruta activa del usuario.
async function actualizarProgresoUsuario() {
    if (!usuarioActual) return;
    const etiquetaPuntos = document.querySelector("#user-points");
    const textoProgreso = document.querySelector("#user-progress-text");
    const porcentajeProgreso = document.querySelector("#user-progress-percent");
    const barraProgreso = document.querySelector("#user-progress-bar");
    const contenedorParadas = document.querySelector(".checkpoints");
    const idRutaActiva = localStorage.getItem("caceresgo-ruta-activa-id");

    try {
        // Espero los datos de progreso para poder actualizar la pantalla.
        const progreso = await solicitarAPI("progress", {
            parametros: { route_id: idRutaActiva || 0 }
        });
        etiquetaPuntos.textContent = progreso.total_points;
        const total = Number(progreso.route.total);
        const visitados = Number(progreso.route.visited);
        const porcentaje = total ? Math.round((visitados / total) * 100) : 0;
        textoProgreso.textContent = total
            ? `${visitados} de ${total} lugares descubiertos`
            : "Selecciona una ruta para ver tus lugares descubiertos";
        porcentajeProgreso.textContent = `${porcentaje}%`;
        barraProgreso.style.width = `${porcentaje}%`;
        if (contenedorParadas && progreso.route.places) {
            contenedorParadas.innerHTML = progreso.route.places.map((lugar, indice) =>
                `<div class="check ${lugar.visited ? "" : "pending"}"><i>${lugar.visited ? "✓" : indice + 1}</i>${escaparTexto(lugar.name)}</div>`
            ).join("");
        }
        pintarRutaEnMapa(idRutaActiva, progreso.route.places || []);
        if (document.body.classList.contains("progress-view")) iniciarSeguimiento();
    } catch (error) {
        textoProgreso.textContent = `No se pudo cargar el progreso: ${error.message}`;
    }
}

// 7. Mapa de la ruta activa y seguimiento en tiempo real
const contenedorSeguimiento = document.querySelector("#route-tracker");
const elementoMapaRuta = document.querySelector("#route-map");
const estadoSeguimiento = document.querySelector("#tracker-status");
const botonSeguimiento = document.querySelector("#tracker-toggle");
const tituloSeguimiento = document.querySelector("#tracker-title");
const resumenSeguimiento = document.querySelector("#tracker-summary");
const tarjetaSiguiente = document.querySelector("#tracker-next");
const listaParadas = document.querySelector("#tracker-stops");
// Servicio gratuito de OpenStreetMap que calcula caminos a pie por las calles.
const urlCaminos = "https://routing.openstreetmap.de/routed-foot/route/v1/foot/";
let mapaRuta = null;
let capaLineaRuta = null;
let capaMarcadores = null;
let capaCamino = null;
let marcadorPosicion = null;
let circuloPrecision = null;
let marcadoresLugares = {};
let idSeguimiento = null;
let seguimientoPausado = false;
let seguirUsuario = true;
let lugaresRutaActiva = [];
let idRutaPintada = null;
let idSiguienteLugar = null;
let distanciaAnterior = null;
let ultimaPosicion = null;
let caminoSiguiente = null;
let momentoUltimoCamino = 0;

// Cambio el texto y el color del aviso del seguimiento.
function actualizarEstadoSeguimiento(mensaje, tipo = "") {
    estadoSeguimiento.textContent = mensaje;
    estadoSeguimiento.className = `tracker-status ${tipo}`.trim();
}

// Distancia en metros entre dos coordenadas (fórmula del semiverseno).
function distanciaEnMetros(latitud1, longitud1, latitud2, longitud2) {
    const radioTierra = 6371000;
    const aRadianes = (grados) => grados * Math.PI / 180;
    const diferenciaLatitud = aRadianes(latitud2 - latitud1);
    const diferenciaLongitud = aRadianes(longitud2 - longitud1);
    const calculo = Math.sin(diferenciaLatitud / 2) ** 2 + Math.cos(aRadianes(latitud1)) * Math.cos(aRadianes(latitud2)) * Math.sin(diferenciaLongitud / 2) ** 2;
    return 2 * radioTierra * Math.asin(Math.sqrt(calculo));
}

// Distancia escrita en metros o en kilómetros.
function textoDistancia(metros) {
    return metros < 1000 ? `${Math.round(metros)} m` : `${(metros / 1000).toFixed(1).replace(".", ",")} km`;
}

// Tiempo andando escrito en minutos.
function textoTiempo(segundos) {
    return `${Math.max(1, Math.round(segundos / 60))} min andando`;
}

// Capa con las calles de OpenStreetMap.
function capaCalles() {
    return L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: "© OpenStreetMap"
    });
}

// Pido el camino a pie entre varios puntos. Si el servicio no responde, devuelvo null y uso líneas rectas.
async function pedirCamino(puntos) {
    try {
        const tramo = puntos.map(([latitud, longitud]) => `${longitud},${latitud}`).join(";");
        // Espero a que el servicio de caminos calcule la ruta por las calles.
        const respuesta = await fetch(`${urlCaminos}${tramo}?overview=full&geometries=geojson`);
        // Espero a leer la respuesta en JSON.
        const datos = await respuesta.json();
        const ruta = datos.routes?.[0];
        if (!ruta) return null;
        return {
            coordenadas: ruta.geometry.coordinates.map(([longitud, latitud]) => [latitud, longitud]),
            distancia: ruta.distance,
            duracion: ruta.duration
        };
    } catch {
        return null;
    }
}

// Chincheta de un lugar: numerada, verde si está validado y más grande si es el siguiente.
function iconoLugar(lugar, esSiguiente) {
    const tamano = esSiguiente ? 40 : 32;
    const estado = lugar.visited ? "visited" : esSiguiente ? "next" : "";
    return L.divIcon({
        className: "",
        html: `<span class="map-pin ${estado}" style="width:${tamano}px;height:${tamano}px"><b>${lugar.visited ? "✓" : lugar.numero}</b></span>`,
        iconSize: [tamano, tamano],
        iconAnchor: [tamano / 2, Math.round(tamano / 2 + tamano * 0.71)],
        popupAnchor: [0, -tamano]
    });
}

// Primer lugar de la ruta que todavía no está validado.
function siguienteLugarRuta() {
    return lugaresRutaActiva.find((lugar) => !lugar.visited);
}

// Latitud y longitud de un lugar en el formato de Leaflet.
function coordenadasLugar(lugar) {
    return [Number(lugar.latitude), Number(lugar.longitude)];
}

// Dibujo una chincheta por lugar: verde si ya está validado y coral, más grande, el siguiente.
function dibujarMarcadores() {
    if (!mapaRuta) return;
    capaMarcadores.clearLayers();
    marcadoresLugares = {};
    const siguiente = siguienteLugarRuta();
    lugaresRutaActiva.forEach((lugar) => {
        marcadoresLugares[lugar.id] = L.marker(coordenadasLugar(lugar), {
            icon: iconoLugar(lugar, lugar === siguiente),
            zIndexOffset: lugar === siguiente ? 1000 : 0
        }).bindPopup(`<strong>${lugar.numero}. ${escaparTexto(lugar.name)}</strong><br>${escaparTexto(lugar.category_name || "Sin categoría")} · ${lugar.points} pts<br>${lugar.visited ? "Ya validado ✓" : lugar === siguiente ? "Tu siguiente parada" : "Pendiente"}`)
            .addTo(capaMarcadores);
    });
}

// Lista de paradas debajo del mapa. Al pulsar una, el mapa va hasta ella.
function pintarParadas() {
    const siguiente = siguienteLugarRuta();
    listaParadas.innerHTML = lugaresRutaActiva.map((lugar) => `<li><button type="button" class="${lugar.visited ? "visited" : lugar === siguiente ? "next" : ""}" data-stop="${lugar.id}"><i>${lugar.visited ? "✓" : lugar.numero}</i><span>${escaparTexto(lugar.name)}</span><small>${escaparTexto(lugar.category_name || "Sin categoría")} · ${lugar.points} pts</small></button></li>`).join("");
}

// Tarjeta con el siguiente lugar, la distancia y el tiempo andando.
function pintarSiguiente(distanciaRecta = null) {
    const siguiente = siguienteLugarRuta();
    if (!siguiente) {
        tarjetaSiguiente.innerHTML = '<span class="next-label">Ruta completada</span><strong>¡Has validado todos los lugares!</strong><small>Mira tus puntos en la clasificación.</small>';
        return;
    }
    let distancia = "Buscando tu posición…";
    if (caminoSiguiente && caminoSiguiente.idLugar === siguiente.id) {
        distancia = `${textoDistancia(caminoSiguiente.distancia)}<br>${textoTiempo(caminoSiguiente.duracion)}`;
    } else if (distanciaRecta !== null) {
        distancia = `${textoDistancia(distanciaRecta)}<br>en línea recta`;
    }
    tarjetaSiguiente.innerHTML = `<span class="next-label">Siguiente parada</span><strong>${siguiente.numero}. ${escaparTexto(siguiente.name)}</strong><small>${escaparTexto(siguiente.category_name || "Sin categoría")} · ${siguiente.points} pts</small><span class="next-distance">${distancia}</span>`;
}

// Pinto en el mapa la ruta activa: chinchetas, línea y lista de paradas.
function pintarRutaEnMapa(idRuta, lugares) {
    // Numero cada lugar según su orden en la ruta y me quedo con los que tienen coordenadas.
    lugaresRutaActiva = [];
    lugares.forEach((lugar, indice) => {
        lugar.numero = indice + 1;
        if (lugar.latitude !== null && lugar.longitude !== null) lugaresRutaActiva.push(lugar);
    });
    contenedorSeguimiento.hidden = !lugaresRutaActiva.length;
    if (!lugaresRutaActiva.length) {
        detenerSeguimiento();
        idRutaPintada = null;
        return;
    }
    tituloSeguimiento.textContent = localStorage.getItem("caceresgo-ruta-activa") || "Ruta en curso";
    pintarParadas();
    let distanciaInicial = null;
    if (ultimaPosicion) {
        const coordenadas = coordenadasLugar(siguienteLugarRuta() || lugaresRutaActiva[0]);
        distanciaInicial = distanciaEnMetros(ultimaPosicion.latitude, ultimaPosicion.longitude, coordenadas[0], coordenadas[1]);
    }
    pintarSiguiente(distanciaInicial);
    if (!window.L) {
        elementoMapaRuta.hidden = true;
        return;
    }
    if (!mapaRuta) {
        mapaRuta = L.map(elementoMapaRuta, { zoomControl: false }).setView([39.4745, -6.3705], 16);
        L.control.zoom({ position: "topright" }).addTo(mapaRuta);
        capaCalles().addTo(mapaRuta);
        capaLineaRuta = L.layerGroup().addTo(mapaRuta);
        capaCamino = L.layerGroup().addTo(mapaRuta);
        capaMarcadores = L.layerGroup().addTo(mapaRuta);
        // Si el usuario mueve el mapa con el dedo, dejo de centrarlo en su posición.
        mapaRuta.on("dragstart", () => { seguirUsuario = false; });
    }
    dibujarMarcadores();
    if (idRutaPintada !== idRuta) {
        idRutaPintada = idRuta;
        distanciaAnterior = null;
        caminoSiguiente = null;
        momentoUltimoCamino = 0;
        capaCamino.clearLayers();
        dibujarLineaRuta();
        window.requestAnimationFrame(() => {
            mapaRuta.invalidateSize();
            verRutaCompleta();
        });
    }
    // Con un lugar recién validado, recalculo enseguida la siguiente parada.
    if (ultimaPosicion) actualizarPosicionRuta({ coords: ultimaPosicion });
}

// Primero uno los lugares en línea recta y, cuando llega el camino real por las calles, lo cambio.
async function dibujarLineaRuta() {
    const idRuta = idRutaPintada;
    const puntos = lugaresRutaActiva.map(coordenadasLugar);
    capaLineaRuta.clearLayers();
    L.polyline(puntos, { color: "#174842", weight: 3, opacity: 0.6, dashArray: "4 8" }).addTo(capaLineaRuta);
    resumenSeguimiento.textContent = `${lugaresRutaActiva.length} ${lugaresRutaActiva.length === 1 ? "lugar" : "lugares"}`;
    if (puntos.length < 2) return;
    // Espero al camino real por las calles.
    const camino = await pedirCamino(puntos);
    if (!camino || idRuta !== idRutaPintada) return;
    capaLineaRuta.clearLayers();
    L.polyline(camino.coordenadas, { color: "#ffffff", weight: 8, opacity: 0.9 }).addTo(capaLineaRuta);
    L.polyline(camino.coordenadas, { color: "#174842", weight: 5 }).addTo(capaLineaRuta);
    resumenSeguimiento.textContent = `${lugaresRutaActiva.length} lugares · ${textoDistancia(camino.distancia)} · ${textoTiempo(camino.duracion)}`;
}

// Camino desde donde está el usuario hasta su siguiente parada. Lo pido como mucho cada 15 segundos.
async function actualizarCaminoHastaSiguiente(latitud, longitud, siguiente) {
    // Si han pasado menos de 15 segundos desde la última vez, no lo vuelvo a pedir.
    const ahora = Date.now();
    if (ahora - momentoUltimoCamino < 15000) return;
    momentoUltimoCamino = ahora;
    // Espero al camino a pie hasta la siguiente parada.
    const camino = await pedirCamino([[latitud, longitud], coordenadasLugar(siguiente)]);
    if (siguienteLugarRuta()?.id !== siguiente.id) return;
    capaCamino.clearLayers();
    if (camino) {
        caminoSiguiente = { idLugar: siguiente.id, distancia: camino.distancia, duracion: camino.duracion };
        L.polyline(camino.coordenadas, { color: "#ee6b54", weight: 5, dashArray: "1 9", lineCap: "round" }).addTo(capaCamino);
    } else {
        caminoSiguiente = null;
        L.polyline([[latitud, longitud], coordenadasLugar(siguiente)], { color: "#ee6b54", weight: 3, dashArray: "2 8" }).addTo(capaCamino);
    }
    const coordenadasSiguiente = coordenadasLugar(siguiente);
    pintarSiguiente(distanciaEnMetros(latitud, longitud, coordenadasSiguiente[0], coordenadasSiguiente[1]));
}

// Encuadro el mapa para que se vea la ruta entera.
function verRutaCompleta() {
    if (!mapaRuta || !lugaresRutaActiva.length) return;
    const puntos = lugaresRutaActiva.map(coordenadasLugar);
    if (ultimaPosicion) puntos.push([ultimaPosicion.latitude, ultimaPosicion.longitude]);
    mapaRuta.fitBounds(puntos, { padding: [40, 40], maxZoom: 17 });
}

// Cada vez que llega una posición nueva, muevo al usuario en el mapa y le digo cómo va.
function actualizarPosicionRuta({ coords: coordenadas }) {
    const { latitude: latitud, longitude: longitud, accuracy: precision, heading: direccion } = coordenadas;
    const primeraPosicion = !ultimaPosicion;
    ultimaPosicion = { latitude: latitud, longitude: longitud, accuracy: precision, heading: direccion };
    const siguiente = siguienteLugarRuta();
    if (mapaRuta) {
        const flecha = direccion === null || direccion === undefined || Number.isNaN(direccion) ? "" : `<i style="transform:rotate(${Math.round(direccion)}deg)"></i>`;
        const icono = L.divIcon({ className: "", html: `<span class="user-dot">${flecha}</span>`, iconSize: [22, 22], iconAnchor: [11, 11] });
        if (!marcadorPosicion) {
            circuloPrecision = L.circle([latitud, longitud], { radius: precision, color: "#174842", weight: 1, fillOpacity: 0.08 }).addTo(mapaRuta);
            marcadorPosicion = L.marker([latitud, longitud], { icon: icono, zIndexOffset: 2000 }).bindPopup("Estás aquí").addTo(mapaRuta);
        } else {
            circuloPrecision.setLatLng([latitud, longitud]).setRadius(precision);
            marcadorPosicion.setLatLng([latitud, longitud]).setIcon(icono);
        }
        if (primeraPosicion && siguiente) {
            mapaRuta.fitBounds([[latitud, longitud], coordenadasLugar(siguiente)], { padding: [60, 60], maxZoom: 18 });
        } else if (seguirUsuario) {
            mapaRuta.panTo([latitud, longitud]);
        }
    }
    if (!siguiente) {
        capaCamino?.clearLayers();
        pintarSiguiente();
        actualizarEstadoSeguimiento("¡Ruta completada! Has validado todos los lugares.", "correcto");
        return;
    }
    if (idSiguienteLugar !== siguiente.id) {
        idSiguienteLugar = siguiente.id;
        distanciaAnterior = null;
        caminoSiguiente = null;
        momentoUltimoCamino = 0;
        dibujarMarcadores();
        pintarParadas();
    }
    const coordenadasSiguiente = coordenadasLugar(siguiente);
    const distancia = distanciaEnMetros(latitud, longitud, coordenadasSiguiente[0], coordenadasSiguiente[1]);
    let consejo = "Camina hacia la chincheta coral.";
    let tipo = "";
    if (distancia <= 40) {
        consejo = "¡Has llegado! Busca el código QR y valida el lugar.";
        tipo = "correcto";
    } else if (distanciaAnterior !== null && distancia < distanciaAnterior - 5) {
        consejo = "Vas bien, te estás acercando.";
        tipo = "correcto";
    } else if (distanciaAnterior !== null && distancia > distanciaAnterior + 5) {
        consejo = "Te estás alejando. Sigue la línea coral.";
        tipo = "error";
    }
    distanciaAnterior = distancia;
    actualizarEstadoSeguimiento(consejo, tipo);
    pintarSiguiente(distancia);
    if (mapaRuta && distancia > 40) actualizarCaminoHastaSiguiente(latitud, longitud, siguiente);
    else capaCamino?.clearLayers();
}

// Empiezo a seguir la posición del usuario mientras está en "Mi progreso".
function iniciarSeguimiento() {
    if (idSeguimiento !== null || seguimientoPausado || !lugaresRutaActiva.length) return;
    if (!navigator.geolocation) {
        actualizarEstadoSeguimiento("Tu navegador no permite obtener la ubicación.", "error");
        return;
    }
    if (!window.isSecureContext) {
        actualizarEstadoSeguimiento("El seguimiento solo funciona con https:// o desde localhost.", "error");
        return;
    }
    actualizarEstadoSeguimiento("Buscando tu posición...");
    botonSeguimiento.textContent = "Pausar seguimiento";
    idSeguimiento = navigator.geolocation.watchPosition(actualizarPosicionRuta, (fallo) => {
        actualizarEstadoSeguimiento(mensajesFalloUbicacion[fallo.code] || "No hemos podido obtener tu ubicación.", "error");
        if (fallo.code === 1) detenerSeguimiento();
    }, { enableHighAccuracy: true, maximumAge: 5000, timeout: 20000 });
}

// Dejo de seguir la posición del usuario.
function detenerSeguimiento() {
    if (idSeguimiento !== null) navigator.geolocation.clearWatch(idSeguimiento);
    idSeguimiento = null;
    distanciaAnterior = null;
}

// Botón para pausar o reanudar el seguimiento.
botonSeguimiento?.addEventListener("click", () => {
    if (idSeguimiento !== null) {
        seguimientoPausado = true;
        detenerSeguimiento();
        botonSeguimiento.textContent = "Reanudar seguimiento";
        actualizarEstadoSeguimiento("Seguimiento en pausa.");
    } else {
        seguimientoPausado = false;
        iniciarSeguimiento();
    }
});

// Botón para centrar el mapa en el usuario.
document.querySelector("#map-center")?.addEventListener("click", () => {
    if (!ultimaPosicion) {
        actualizarEstadoSeguimiento("Todavía no tengo tu posición. Permite la ubicación para centrarte.", "error");
        return;
    }
    seguirUsuario = true;
    mapaRuta?.flyTo([ultimaPosicion.latitude, ultimaPosicion.longitude], 18);
});

// Botón para ver la ruta completa.
document.querySelector("#map-overview")?.addEventListener("click", () => {
    seguirUsuario = false;
    verRutaCompleta();
});

// Al pulsar una parada de la lista, el mapa va hasta ella.
listaParadas?.addEventListener("click", (evento) => {
    const boton = evento.target.closest("[data-stop]");
    if (!boton || !mapaRuta) return;
    const lugar = lugaresRutaActiva.find((elemento) => String(elemento.id) === boton.dataset.stop);
    if (!lugar) return;
    seguirUsuario = false;
    mapaRuta.flyTo(coordenadasLugar(lugar), 18);
    marcadoresLugares[lugar.id]?.openPopup();
    elementoMapaRuta.scrollIntoView({ behavior: "smooth", block: "center" });
});

// 8. Clasificación, actividad y estadísticas
// Nombre de la persona con una marca si es el usuario conectado.
function nombreConMarca(persona) {
    const esUsuarioActual = usuarioActual && Number(persona.id) === Number(usuarioActual.id);
    return `${escaparTexto(persona.name)}${esUsuarioActual ? " ✦" : ""}`;
}

// Texto "1 lugar" o "N lugares".
function textoLugares(cantidad) {
    return `${cantidad} ${Number(cantidad) === 1 ? "lugar" : "lugares"}`;
}

// Iniciales del nombre y del primer apellido para el círculo de cada persona.
function inicialesDe(nombre) {
    return nombre.trim().split(/\s+/).slice(0, 2).map((palabra) => palabra.charAt(0)).join("").toUpperCase();
}

// Fila de una clasificación: puesto, círculo con iniciales, nombre, detalle, barra comparada con el primero y puntos.
function filaClasificacion(persona, indice, detalle, puntosDelPrimero) {
    const esUsuarioActual = usuarioActual && Number(persona.id) === Number(usuarioActual.id);
    const porcentaje = Math.max(4, Math.round(Number(persona.points) / Number(puntosDelPrimero) * 100));
    const clases = ["rank", indice < 3 ? `top-${indice + 1}` : "", esUsuarioActual ? "mine" : ""].join(" ").trim();
    return `<div class="${clases}"><b>${String(indice + 1).padStart(2, "0")}</b><span class="rank-avatar">${escaparTexto(inicialesDe(persona.name))}</span><span class="rank-info"><span class="rank-name">${nombreConMarca(persona)}</span><em>${detalle}</em><span class="rank-bar"><i style="width:${porcentaje}%"></i></span></span><small><strong>${persona.points}</strong>pts</small></div>`;
}

// Podio del mes: el primero en el centro, el segundo a la izquierda y el tercero a la derecha.
function pintarPodio(personas) {
    const podio = document.querySelector("#ranking-month");
    if (!personas.length) {
        podio.innerHTML = '<p class="rank-empty">Todavía nadie ha sumado puntos este mes.</p>';
        return;
    }
    const orden = [1, 0, 2].filter((posicion) => personas[posicion]);
    podio.innerHTML = orden.map((posicion) => {
        const persona = personas[posicion];
        // Iniciales del nombre y del primer apellido para el círculo, y el nombre corto debajo.
        const palabras = persona.name.trim().split(/\s+/);
        const iniciales = inicialesDe(persona.name);
        const esUsuarioActual = usuarioActual && Number(persona.id) === Number(usuarioActual.id);
        return `<div class="podium-step puesto-${posicion + 1}" title="${escaparTexto(persona.name)} · ${persona.points} puntos · ${textoLugares(persona.places)}">${posicion === 0 ? '<span class="podium-star" aria-hidden="true">✦</span>' : ""}<span class="podium-avatar">${escaparTexto(iniciales)}</span><strong>${escaparTexto(palabras.slice(0, 2).join(" "))}${esUsuarioActual ? " ✦" : ""}</strong><div class="podium-base"><span class="podium-number">${posicion + 1}</span><span class="podium-points">${persona.points} pts</span></div></div>`;
    }).join("");
}

// Texto de cuánto tiempo hace una visita.
function textoHace(segundos) {
    if (segundos < 60) return "ahora mismo";
    if (segundos < 3600) return `hace ${Math.floor(segundos / 60)} min`;
    if (segundos < 86400) return `hace ${Math.floor(segundos / 3600)} h`;
    const dias = Math.floor(segundos / 86400);
    return `hace ${dias} ${dias === 1 ? "día" : "días"}`;
}

// Cargo las últimas visitas de todos los exploradores.
async function cargarActividad() {
    const lista = document.querySelector("#activity-list");
    try {
        // Espero a que el servidor me devuelva las últimas visitas validadas.
        const { activity: actividad } = await solicitarAPI("activity");
        lista.innerHTML = actividad.length
            ? actividad.map((visita) => `<li><span class="rank-avatar">${escaparTexto(inicialesDe(visita.name))}</span><span><strong>${escaparTexto(visita.name)}</strong> ha validado <strong>${escaparTexto(visita.place_name)}</strong><small>${escaparTexto(visita.route_name)} · +${visita.points} pts</small></span><time>${textoHace(Number(visita.seconds_ago))}</time></li>`).join("")
            : '<li class="rank-empty">Todavía no se ha validado ningún lugar.</li>';
    } catch (error) {
        lista.innerHTML = `<li class="rank-empty">No se ha podido cargar la actividad: ${escaparTexto(error.message)}</li>`;
        console.error("No se pudo cargar la actividad:", error);
    }
}

// Cargo el podio del mes, el top 5 de la semana y la clasificación general.
async function cargarClasificacion() {
    try {
        // Espero a que el servidor me devuelva la clasificación general, la del mes y la de la semana.
        const { ranking: general, month: mejoresMes, week: mejoresSemana } = await solicitarAPI("ranking");
        pintarPodio(mejoresMes);
        document.querySelector("#ranking-week").innerHTML = mejoresSemana.length
            ? mejoresSemana.map((persona, indice) => filaClasificacion(persona, indice, textoLugares(persona.places), mejoresSemana[0].points)).join("")
            : '<p class="rank-empty">Todavía nadie ha sumado puntos esta semana.</p>';
        document.querySelector("#ranking-general").innerHTML = general.length
            ? general.map((persona, indice) => filaClasificacion(persona, indice, `${persona.routes} ${Number(persona.routes) === 1 ? "ruta terminada" : "rutas terminadas"} · ${textoLugares(persona.places)}`, general[0].points)).join("")
            : '<p class="rank-empty">Todavía no hay puntos. ¡Sé la primera persona en validar un lugar!</p>';
    } catch (error) {
        // Si el servidor falla, lo digo en la pantalla para saber qué pasa.
        document.querySelector("#ranking-general").innerHTML = `<p class="rank-empty">No se ha podido cargar la clasificación: ${escaparTexto(error.message)}</p>`;
        console.error("No se pudo cargar la clasificación:", error);
    }
}

// Cargo los datos generales de la portada.
async function cargarEstadisticasPublicas() {
    try {
        // Espero a que el servidor me devuelva las estadísticas.
        const estadisticas = await solicitarAPI("stats");
        document.querySelector("#route-count").textContent = estadisticas.routes;
        document.querySelector("#visit-count").textContent = estadisticas.visits;
        document.querySelector("#user-count").textContent = estadisticas.users;
    } catch (error) {
        console.error("No se pudieron cargar las estadísticas:", error);
    }
}

// 9. Panel de administración
const botonSalirAdministrador = document.querySelector("#admin-exit");
const pestanasAdministrador = document.querySelectorAll("[data-admin-tab]");
const vistasAdministrador = document.querySelectorAll("[data-admin-view]");
const formularioRuta = document.querySelector("#route-form");
const campoIdRuta = document.querySelector("#route-id");
const campoNombreRuta = document.querySelector("#route-name");
const campoDescripcionRuta = document.querySelector("#route-description");
const campoDuracionRuta = document.querySelector("#route-duration");
const tituloFormularioRuta = document.querySelector("#route-form-title");
const cancelarEdicionRuta = document.querySelector("#route-cancel");
const mensajeRutaAdministrador = document.querySelector("#route-message");
const listaRutas = document.querySelector("#admin-routes-list");
const listaLugares = document.querySelector("#admin-places-list");
const listaUsuarios = document.querySelector("#admin-users-list");
const listaResultados = document.querySelector("#admin-results-list");
const ventanaLugar = document.querySelector("#place-modal");
const formularioLugar = document.querySelector("#place-form");
const campoIdLugar = document.querySelector("#place-id");
const campoNombreLugar = document.querySelector("#place-name");
const campoCodigoLugar = document.querySelector("#place-code");
const campoCategoriaLugar = document.querySelector("#place-category");
const formularioCategoria = document.querySelector("#category-form");
const campoIdCategoria = document.querySelector("#category-id");
const campoNombreCategoria = document.querySelector("#category-name");
const campoPuntosCategoria = document.querySelector("#category-points");
const tituloFormularioCategoria = document.querySelector("#category-form-title");
const cancelarEdicionCategoria = document.querySelector("#category-cancel");
const mensajeCategoria = document.querySelector("#category-message");
const listaCategorias = document.querySelector("#admin-categories-list");

// Escapo el texto antes de ponerlo en la página para evitar código malicioso.
function escaparTexto(valor) {
    return String(valor).replace(/[&<>'"]/g, (caracter) => ({
        "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
    }[caracter]));
}

// Listado de rutas del panel.
async function mostrarRutasAdministrador() {
    // Espero a que el servidor me devuelva las rutas para el panel.
    const { routes: rutas } = await solicitarAPI("admin-routes");
    rutasEnCache = rutas;
    document.querySelector("#route-total").textContent = rutasEnCache.length;
    listaRutas.innerHTML = rutasEnCache.length
        ? rutasEnCache.map((ruta) => `<div class="admin-item${Number(ruta.id) === Number(idRutaSeleccionada) ? " selected" : ""}" data-route-item="${ruta.id}"><div><strong>${escaparTexto(ruta.name)}</strong><small>${escaparTexto(ruta.duration || "")} · ${ruta.total_places} ${Number(ruta.total_places) === 1 ? "lugar" : "lugares"} · ${ruta.points} puntos</small></div><div class="admin-item-actions"><button type="button" data-select-route="${ruta.id}">Lugares</button><button type="button" data-edit-route="${ruta.id}">Editar</button><button type="button" data-delete-route="${ruta.id}">Eliminar</button></div></div>`).join("")
        : '<p class="empty-admin">Todavía no hay recorridos.</p>';
    if (!idRutaSeleccionada || !rutasEnCache.some((ruta) => Number(ruta.id) === Number(idRutaSeleccionada))) {
        idRutaSeleccionada = rutasEnCache[0]?.id || null;
    }
    // Cargo los lugares de la ruta seleccionada cuando ya tengo la lista de rutas.
    await mostrarLugaresAdministrador();
}

// Listado de lugares de la ruta seleccionada.
async function mostrarLugaresAdministrador() {
    if (!idRutaSeleccionada) {
        lugaresEnCache = [];
        listaLugares.innerHTML = '<p class="empty-admin">Selecciona un recorrido y añade sus lugares de interés.</p>';
        return;
    }
    // Marco la ruta elegida y pongo su nombre encima de sus lugares.
    const rutaSeleccionada = rutasEnCache.find((ruta) => Number(ruta.id) === Number(idRutaSeleccionada));
    document.querySelector("#places-title").textContent = `Lugares de interés de «${rutaSeleccionada?.name || ""}»`;
    listaRutas.querySelectorAll("[data-route-item]").forEach((elemento) => elemento.classList.toggle("selected", Number(elemento.dataset.routeItem) === Number(idRutaSeleccionada)));
    // Espero los lugares de la ruta seleccionada.
    const { places: lugares } = await solicitarAPI("admin-places", {
        parametros: { route_id: idRutaSeleccionada }
    });
    lugaresEnCache = lugares;
    listaLugares.innerHTML = lugaresEnCache.length
        ? lugaresEnCache.map((lugar) => `<div class="admin-item"><div><strong>${escaparTexto(lugar.name)}</strong><small>QR: ${escaparTexto(lugar.qr_code)} · ${escaparTexto(lugar.category_name || "Sin categoría")} · ${lugar.points} puntos</small></div><div class="admin-item-actions"><button type="button" data-qr-place="${lugar.id}">QR</button><button type="button" data-edit-place="${lugar.id}">Editar</button><button type="button" data-delete-place="${lugar.id}">Eliminar</button></div></div>`).join("")
        : '<p class="empty-admin">Añade los lugares de este recorrido.</p>';
}

// Listado de categorías y sus puntos.
async function mostrarCategoriasAdministrador() {
    // Espero a que el servidor me devuelva las categorías.
    const { categories: categorias } = await solicitarAPI("admin-categories");
    categoriasEnCache = categorias;
    document.querySelector("#category-total").textContent = categorias.length;
    listaCategorias.innerHTML = categorias.length
        ? categorias.map((categoria) => `<div class="admin-item"><div><strong>${escaparTexto(categoria.name)}</strong><small>${categoria.points} puntos · ${categoria.total_places} ${Number(categoria.total_places) === 1 ? "lugar" : "lugares"}</small></div><div class="admin-item-actions"><button type="button" data-edit-category="${categoria.id}">Editar</button><button type="button" data-delete-category="${categoria.id}">Eliminar</button></div></div>`).join("")
        : '<p class="empty-admin">Todavía no hay categorías.</p>';
    // El desplegable del lugar muestra los puntos que da cada categoría.
    campoCategoriaLugar.innerHTML = '<option value="">Elige una categoría</option>' + categorias.map((categoria) =>
        `<option value="${categoria.id}">${escaparTexto(categoria.name)} · ${categoria.points} puntos</option>`
    ).join("");
}

// Listado de cuentas con su estado.
async function mostrarUsuariosAdministrador() {
    // Espero a que el servidor me devuelva las cuentas.
    const { users: usuarios } = await solicitarAPI("admin-users");
    document.querySelector("#user-total").textContent = usuarios.length;
    listaUsuarios.innerHTML = usuarios.length
        ? usuarios.map((usuario) => `<div class="admin-item"><div><strong>${escaparTexto(usuario.name)}</strong><small>${escaparTexto(usuario.email)}</small></div><div class="admin-item-actions"><span class="status-pill">${usuario.status === "blocked" ? "bloqueada" : "activa"}</span>${Number(usuario.id) === Number(usuarioActual?.id) ? '<span class="status-pill">tu cuenta</span>' : `<button type="button" data-toggle-user="${usuario.id}" data-current-status="${usuario.status}">${usuario.status === "blocked" ? "Activar" : "Bloquear"}</button>`}</div></div>`).join("")
        : '<p class="empty-admin">Todavía no hay cuentas.</p>';
}

// Listado de rutas terminadas por cada participante.
async function mostrarResultadosAdministrador() {
    // Espero a que el servidor me devuelva los resultados.
    const { results: resultados } = await solicitarAPI("admin-results");
    document.querySelector("#result-total").textContent = resultados.length;
    listaResultados.innerHTML = resultados.length
        ? resultados.map((resultado) => `<div class="admin-item"><div><strong>${escaparTexto(resultado.user_name)} · ${escaparTexto(resultado.route_name)}</strong><small>${new Date(resultado.completed_at).toLocaleDateString("es-ES")}</small></div><strong>${resultado.points} puntos</strong></div>`).join("")
        : '<p class="empty-admin">Todavía no hay rutas terminadas.</p>';
}

// Abro el panel de administración y cargo sus listados.
async function abrirPanelAdministrador() {
    if (usuarioActual?.role !== "admin") {
        mostrarPagina("home");
        return;
    }
    try {
        // Espero a que terminen las cuatro cargas; se hacen al mismo tiempo.
        await Promise.all([
            mostrarRutasAdministrador(),
            mostrarCategoriasAdministrador(),
            mostrarUsuariosAdministrador(),
            mostrarResultadosAdministrador()
        ]);
        mostrarPagina("admin");
    } catch (error) {
        alert(`No se pudo cargar el panel de administración: ${error.message}`);
    }
}

// Pestañas del panel de administración.
pestanasAdministrador.forEach((pestana) => pestana.addEventListener("click", () => {
    pestanasAdministrador.forEach((elemento) => elemento.classList.toggle("active", elemento === pestana));
    vistasAdministrador.forEach((vista) => vista.classList.toggle("active", vista.dataset.adminView === pestana.dataset.adminTab));
}));

// Creo o edito una ruta.
formularioRuta?.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    const datosRuta = {
        name: campoNombreRuta.value.trim(),
        description: campoDescripcionRuta.value.trim(),
        duration: campoDuracionRuta.value.trim(),
        status: "published"
    };
    const esEdicion = Boolean(campoIdRuta.value);
    try {
        // Espero a que el servidor guarde o actualice el recorrido.
        await solicitarAPI("admin-route", {
            metodo: esEdicion ? "PUT" : "POST",
            parametros: esEdicion ? { id: campoIdRuta.value } : undefined,
            datos: datosRuta
        });
        formularioRuta.reset();
        campoIdRuta.value = "";
        tituloFormularioRuta.textContent = "Nuevo recorrido";
        cancelarEdicionRuta.hidden = true;
        mensajeRutaAdministrador.textContent = "Recorrido guardado correctamente.";
        // Refresco primero la lista de administración.
        await mostrarRutasAdministrador();
        // Actualizo también las rutas que ven los visitantes.
        await cargarRutasPublicas();
        // Actualizo el contador de estadísticas.
        await cargarEstadisticasPublicas();
    } catch (error) {
        mostrarError(mensajeRutaAdministrador, error, "No se ha podido guardar el recorrido.");
    }
});

// Cancelo la edición de una ruta.
cancelarEdicionRuta?.addEventListener("click", () => {
    formularioRuta.reset();
    campoIdRuta.value = "";
    tituloFormularioRuta.textContent = "Nuevo recorrido";
    cancelarEdicionRuta.hidden = true;
});

// Botones de cada ruta del listado: lugares, editar y borrar.
listaRutas?.addEventListener("click", async (evento) => {
    const boton = evento.target.closest("button");
    if (!boton) return;
    const identificador = boton.dataset.selectRoute || boton.dataset.editRoute || boton.dataset.deleteRoute;
    const ruta = rutasEnCache.find((elemento) => String(elemento.id) === identificador);
    if (!ruta) return;

    if (boton.dataset.selectRoute) {
        idRutaSeleccionada = ruta.id;
        try {
            // Espero a que se muestren los lugares de la ruta elegida.
            await mostrarLugaresAdministrador();
            // Bajo hasta los lugares para que se vean.
            document.querySelector(".places-area").scrollIntoView({ behavior: "smooth", block: "start" });
        }
        catch (error) { alert(`No se pudieron cargar los lugares: ${error.message}`); }
        return;
    }
    if (boton.dataset.editRoute) {
        campoIdRuta.value = ruta.id;
        campoNombreRuta.value = ruta.name;
        campoDescripcionRuta.value = ruta.description || "";
        campoDuracionRuta.value = ruta.duration || "";
        tituloFormularioRuta.textContent = "Editar recorrido";
        cancelarEdicionRuta.hidden = false;
        return;
    }
    if (boton.dataset.deleteRoute && confirm(`¿Eliminar "${ruta.name}"?`)) {
        try {
            // Espero a que el servidor elimine el recorrido.
            await solicitarAPI("admin-route", { metodo: "DELETE", parametros: { id: ruta.id } });
            // Actualizo la lista del panel después de eliminarlo.
            await mostrarRutasAdministrador();
            // Quito el recorrido eliminado de la vista pública.
            await cargarRutasPublicas();
            // Actualizo el contador de estadísticas.
            await cargarEstadisticasPublicas();
        } catch (error) {
            alert(`No se pudo eliminar el recorrido: ${error.message}`);
        }
    }
});

// Abro la ventana para añadir un lugar a la ruta seleccionada.
document.querySelector("#place-add")?.addEventListener("click", () => {
    if (!idRutaSeleccionada) return;
    formularioLugar.reset();
    campoIdLugar.value = "";
    ventanaLugar.classList.add("open");
});

// Creo o edito un lugar.
formularioLugar?.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    if (!idRutaSeleccionada) return;
    const datosLugar = {
        name: campoNombreLugar.value.trim(),
        qr_code: campoCodigoLugar.value.trim().toUpperCase(),
        category_id: Number(campoCategoriaLugar.value),
        route_id: Number(idRutaSeleccionada)
    };
    const esEdicion = Boolean(campoIdLugar.value);
    const mensajeLugar = document.querySelector("#place-message");
    try {
        // Espero a que el servidor guarde o actualice el lugar.
        await solicitarAPI("admin-place", {
            metodo: esEdicion ? "PUT" : "POST",
            parametros: esEdicion ? { id: campoIdLugar.value } : undefined,
            datos: datosLugar
        });
        ventanaLugar.classList.remove("open");
        // Actualizo las rutas (sus puntos cambian) y la lista de lugares.
        await mostrarRutasAdministrador();
        // Actualizo cuántos lugares tiene cada categoría.
        await mostrarCategoriasAdministrador();
    } catch (error) {
        mostrarError(mensajeLugar, error, "No se ha podido guardar el lugar.");
    }
});

// Códigos QR de los lugares para imprimirlos
const ventanaQr = document.querySelector("#qr-modal");
const hojaQr = document.querySelector("#qr-sheet");

// El QR lleva un enlace a la aplicación con la clave, para que la cámara normal del móvil también sirva.
function enlaceValidacion(clave) {
    return `${window.location.origin}${window.location.pathname}?clave=${encodeURIComponent(clave)}`;
}

// Dibujo un código QR en un canvas y lo devuelvo como imagen PNG.
function dibujarQr(texto) {
    const codigo = qrcode(0, "M");
    codigo.addData(texto);
    codigo.make();
    const modulos = codigo.getModuleCount();
    const tamano = 8;
    const margen = 4;
    const lienzo = document.createElement("canvas");
    lienzo.width = lienzo.height = (modulos + margen * 2) * tamano;
    const contexto = lienzo.getContext("2d");
    contexto.fillStyle = "#ffffff";
    contexto.fillRect(0, 0, lienzo.width, lienzo.height);
    contexto.fillStyle = "#102b2a";
    for (let fila = 0; fila < modulos; fila++) {
        for (let columna = 0; columna < modulos; columna++) {
            if (codigo.isDark(fila, columna)) contexto.fillRect((columna + margen) * tamano, (fila + margen) * tamano, tamano, tamano);
        }
    }
    return lienzo.toDataURL("image/png");
}

// Muestro la hoja con los QR de todos los lugares de la ruta.
function mostrarCodigosQr(lugares) {
    if (!window.qrcode) {
        alert("No se ha podido cargar el generador de códigos QR. Comprueba la conexión a internet.");
        return;
    }
    const ruta = rutasEnCache.find((elemento) => Number(elemento.id) === Number(idRutaSeleccionada));
    document.querySelector("#qr-title").textContent = lugares.length === 1 ? lugares[0].name : `Códigos QR de «${ruta?.name || ""}»`;
    hojaQr.innerHTML = lugares.map((lugar) => `<figure class="qr-card"><img src="${dibujarQr(enlaceValidacion(lugar.qr_code))}" alt="Código QR de ${escaparTexto(lugar.name)}"><figcaption><strong>${escaparTexto(lugar.name)}</strong><span>Clave: ${escaparTexto(lugar.qr_code)}</span><small>${escaparTexto(ruta?.name || "")} · ${lugar.points} puntos</small></figcaption></figure>`).join("");
    ventanaQr.classList.add("open");
}

// Botones para ver e imprimir los QR.
document.querySelector("#places-qr")?.addEventListener("click", () => {
    if (lugaresEnCache.length) mostrarCodigosQr(lugaresEnCache);
});

document.querySelector("#qr-print")?.addEventListener("click", () => {
    document.body.classList.add("printing-qr");
    window.print();
});
// Al terminar de imprimir, vuelvo a la vista normal.
window.addEventListener("afterprint", () => document.body.classList.remove("printing-qr"));

// Botones de cada lugar del listado: QR, editar y borrar.
listaLugares?.addEventListener("click", async (evento) => {
    const boton = evento.target.closest("button");
    if (!boton) return;
    const identificador = boton.dataset.qrPlace || boton.dataset.editPlace || boton.dataset.deletePlace;
    const lugar = lugaresEnCache.find((elemento) => String(elemento.id) === identificador);
    if (!lugar) return;

    if (boton.dataset.qrPlace) {
        mostrarCodigosQr([lugar]);
    } else if (boton.dataset.editPlace) {
        campoIdLugar.value = lugar.id;
        campoNombreLugar.value = lugar.name;
        campoCodigoLugar.value = lugar.qr_code;
        campoCategoriaLugar.value = lugar.category_id || "";
        ventanaLugar.classList.add("open");
    } else if (confirm(`¿Eliminar "${lugar.name}"?`)) {
        try {
            // Espero a que el servidor elimine el lugar.
            await solicitarAPI("admin-place", { metodo: "DELETE", parametros: { id: lugar.id } });
            // Actualizo las rutas y la lista de lugares después de eliminarlo.
            await mostrarRutasAdministrador();
        } catch (error) {
            alert(`No se pudo eliminar el lugar: ${error.message}`);
        }
    }
});

// Creo o edito una categoría.
formularioCategoria?.addEventListener("submit", async (evento) => {
    evento.preventDefault();
    const datosCategoria = {
        name: campoNombreCategoria.value.trim(),
        points: Number(campoPuntosCategoria.value)
    };
    const esEdicion = Boolean(campoIdCategoria.value);
    try {
        // Espero a que el servidor guarde o actualice la categoría.
        await solicitarAPI("admin-category", {
            metodo: esEdicion ? "PUT" : "POST",
            parametros: esEdicion ? { id: campoIdCategoria.value } : undefined,
            datos: datosCategoria
        });
        formularioCategoria.reset();
        campoIdCategoria.value = "";
        tituloFormularioCategoria.textContent = "Nueva categoría";
        cancelarEdicionCategoria.hidden = true;
        mensajeCategoria.textContent = "Categoría guardada correctamente.";
        // Refresco las categorías, las rutas y los lugares, porque sus puntos pueden haber cambiado.
        await mostrarCategoriasAdministrador();
        await mostrarRutasAdministrador();
    } catch (error) {
        mostrarError(mensajeCategoria, error, "No se ha podido guardar la categoría.");
    }
});

// Cancelo la edición de una categoría.
cancelarEdicionCategoria?.addEventListener("click", () => {
    formularioCategoria.reset();
    campoIdCategoria.value = "";
    tituloFormularioCategoria.textContent = "Nueva categoría";
    cancelarEdicionCategoria.hidden = true;
});

// Botones de cada categoría: editar y borrar.
listaCategorias?.addEventListener("click", async (evento) => {
    const boton = evento.target.closest("button");
    if (!boton) return;
    const identificador = boton.dataset.editCategory || boton.dataset.deleteCategory;
    const categoria = categoriasEnCache.find((elemento) => String(elemento.id) === identificador);
    if (!categoria) return;

    if (boton.dataset.editCategory) {
        campoIdCategoria.value = categoria.id;
        campoNombreCategoria.value = categoria.name;
        campoPuntosCategoria.value = categoria.points;
        tituloFormularioCategoria.textContent = "Editar categoría";
        cancelarEdicionCategoria.hidden = false;
        mensajeCategoria.textContent = "";
    } else if (confirm(`¿Eliminar la categoría "${categoria.name}"?`)) {
        try {
            // Espero a que el servidor elimine la categoría.
            await solicitarAPI("admin-category", { metodo: "DELETE", parametros: { id: categoria.id } });
            // Actualizo la lista después de eliminarla.
            await mostrarCategoriasAdministrador();
        } catch (error) {
            mensajeCategoria.textContent = error.message;
        }
    }
});

// Bloqueo o desbloqueo una cuenta.
listaUsuarios?.addEventListener("click", async (evento) => {
    const boton = evento.target.closest("button");
    if (!boton || !boton.dataset.toggleUser) return;
    const nuevoEstado = boton.dataset.currentStatus === "blocked" ? "active" : "blocked";
    try {
        // Espero a que el servidor cambie el estado de la cuenta.
        await solicitarAPI("admin-user-status", {
            metodo: "PATCH",
            parametros: { id: boton.dataset.toggleUser },
            datos: { status: nuevoEstado }
        });
        // Refresco la lista para mostrar el nuevo estado.
        await mostrarUsuariosAdministrador();
    } catch (error) {
        alert(`No se pudo cambiar el estado de la cuenta: ${error.message}`);
    }
});

// Salgo del panel cerrando la sesión.
botonSalirAdministrador?.addEventListener("click", async () => {
    try {
        // Espero a que el servidor cierre la sesión de administración.
        await solicitarAPI("logout", { metodo: "POST" });
        limpiarUsuarioConectado();
        mostrarPagina("home");
    } catch (error) {
        alert(`No se pudo cerrar la sesión: ${error.message}`);
    }
});

// 10. Acceso y comprobación del administrador
document.querySelector("#admin-open")?.addEventListener("click", () => {
    if (usuarioActual?.role === "admin") abrirPanelAdministrador();
});

// 11. Carga inicial de la aplicación
(async function iniciarAplicacion() {
    crearMapa();
    // Compruebo primero si ya hay una sesión iniciada.
    await restaurarSesion();
    // Espero a que terminen las tres cargas; se hacen al mismo tiempo.
    await Promise.all([
        cargarRutasPublicas(),
        cargarEstadisticasPublicas(),
        cargarClasificacion()
    ]);
    // Si la app se ha abierto desde el QR de un lugar, preparo la validación de esa clave.
    const claveEnlace = new URLSearchParams(window.location.search).get("clave");
    if (claveEnlace) {
        window.history.replaceState(null, "", window.location.pathname);
        claveRuta.value = extraerClave(claveEnlace);
        ventanaRuta.classList.add("open");
        if (usuarioActual) {
            botonValidarRuta.click();
        } else {
            mensajeRuta.textContent = "Inicia sesión y pulsa Validar visita para sumar este lugar.";
        }
    }
    // Restauro la vista de administración solo para una sesión autorizada.
    if (usuarioActual?.role === "admin") {
        await abrirPanelAdministrador();
    } else if (usuarioActual) {
        await actualizarProgresoUsuario();
    }
    // Espero a que se cargue la actividad de los exploradores.
    await cargarActividad();
})();
