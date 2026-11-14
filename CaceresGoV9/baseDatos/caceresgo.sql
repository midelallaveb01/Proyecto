-- CáceresGO · base de datos completa para XAMPP
-- Importar en phpMyAdmin SIN seleccionar ninguna base de datos (pestaña Importar).
-- Borra la base caceresgo si ya existe y la crea de nuevo con sus tablas, las 5 rutas, las 6 categorías,
-- los 21 lugares, la cuenta del administrador y los 15 participantes de prueba con sus visitas.

DROP DATABASE IF EXISTS caceresgo;

CREATE DATABASE IF NOT EXISTS caceresgo
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE caceresgo;
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(190) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('participant', 'admin') NOT NULL DEFAULT 'participant',
  status ENUM('active', 'blocked') NOT NULL DEFAULT 'active',
  birth_date DATE NULL,
  city VARCHAR(120) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS routes (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(180) NOT NULL,
  description TEXT NULL,
  duration VARCHAR(40) NOT NULL,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'published',
  created_by INT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_routes_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS categories (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80) NOT NULL UNIQUE,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS places (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  route_id INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NULL,
  name VARCHAR(180) NOT NULL,
  description TEXT NULL,
  qr_code VARCHAR(80) NOT NULL UNIQUE,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  latitude DECIMAL(10,7) NULL,
  longitude DECIMAL(10,7) NULL,
  order_index INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_places_route FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
  CONSTRAINT fk_places_category FOREIGN KEY (category_id) REFERENCES categories(id),
  INDEX idx_places_route (route_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS visits (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  route_id INT UNSIGNED NOT NULL,
  place_id INT UNSIGNED NOT NULL,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  validated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_visits_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_visits_route FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
  CONSTRAINT fk_visits_place FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE,
  UNIQUE KEY uq_user_place (user_id, place_id),
  INDEX idx_visits_route (route_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS route_completions (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  route_id INT UNSIGNED NOT NULL,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  completed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_completions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_completions_route FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
  UNIQUE KEY uq_user_route (user_id, route_id),
  INDEX idx_completions_route (route_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cuenta de administración del Ayuntamiento (no se puede crear desde el registro).
INSERT INTO users (name, email, password_hash, role, status)
VALUES ('Carolina Rodríguez Muriel', 'carolina@aytocaceres.com', '$2y$10$opU288eT3hFmbmWZC34t9uJ.N914.YX48tfQzWCiwBAEvX3GTg78a', 'admin', 'active')
ON DUPLICATE KEY UPDATE role = 'admin', status = 'active', password_hash = VALUES(password_hash);

INSERT INTO routes (name, description, duration, points, status)
SELECT 'Secretos de la Ciudad Monumental', 'Descubre los rincones imprescindibles de la ciudad monumental.', '90 min', 350, 'published'
WHERE NOT EXISTS (SELECT 1 FROM routes WHERE name = 'Secretos de la Ciudad Monumental');

INSERT INTO routes (name, description, duration, points, status)
SELECT 'Cáceres de leyenda', 'Historias y leyendas para recorrer Cáceres de otra manera.', '60 min', 280, 'published'
WHERE NOT EXISTS (SELECT 1 FROM routes WHERE name = 'Cáceres de leyenda');

INSERT INTO routes (name, description, duration, points, status)
SELECT 'Pequeños exploradores', 'Una aventura familiar para descubrir la ciudad jugando.', '45 min', 180, 'published'
WHERE NOT EXISTS (SELECT 1 FROM routes WHERE name = 'Pequeños exploradores');

-- Categorías de los lugares. Los puntos de cada lugar son los de su categoría.
INSERT IGNORE INTO categories (name, points) VALUES
  ('Monumento', 60),
  ('Palacio y casa noble', 50),
  ('Iglesia y convento', 45),
  ('Museo', 40),
  ('Plaza y calle', 35),
  ('Mirador', 30);

INSERT INTO places (route_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, 'Arco de la Estrella', 'Entrada principal a la Ciudad Monumental.', 'ESTRELLA24', 50, 39.4753, -6.3717, 1
FROM routes r
WHERE r.name = 'Secretos de la Ciudad Monumental'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'ESTRELLA24');

INSERT INTO places (route_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, 'Plaza Mayor', 'Punto de encuentro de la ciudad histórica.', 'PLAZA24', 50, 39.4758, -6.3709, 2
FROM routes r
WHERE r.name = 'Secretos de la Ciudad Monumental'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'PLAZA24');

INSERT INTO places (route_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, 'Casa del Sol', 'Uno de los rincones con más historia de Cáceres.', 'CASASOL24', 50, 39.4761, -6.3712, 1
FROM routes r
WHERE r.name = 'Cáceres de leyenda'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'CASASOL24');

INSERT INTO places (route_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, 'Palacio de Carvajal', 'Palacio histórico junto a la Plaza de Santa María.', 'CARVAJAL24', 50, 39.4750, -6.3705, 2
FROM routes r
WHERE r.name = 'Cáceres de leyenda'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'CARVAJAL24');

INSERT INTO places (route_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, 'San Jorge', 'Un lugar pensado para descubrir en familia.', 'SANJORGE24', 45, 39.4728, -6.3699, 1
FROM routes r
WHERE r.name = 'Pequeños exploradores'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'SANJORGE24');

-- Categoría de cada lugar de ejemplo.
UPDATE places p JOIN categories c ON c.name = 'Monumento' SET p.category_id = c.id, p.points = c.points WHERE p.qr_code = 'ESTRELLA24';
UPDATE places p JOIN categories c ON c.name = 'Plaza y calle' SET p.category_id = c.id, p.points = c.points WHERE p.qr_code IN ('PLAZA24', 'SANJORGE24');
UPDATE places p JOIN categories c ON c.name = 'Palacio y casa noble' SET p.category_id = c.id, p.points = c.points WHERE p.qr_code IN ('CASASOL24', 'CARVAJAL24');

-- Rutas nuevas.
INSERT INTO routes (name, description, duration, status)
SELECT 'Torres y murallas', 'Recorre la muralla almohade y sus torres más conocidas.', '75 min', 'published'
WHERE NOT EXISTS (SELECT 1 FROM routes WHERE name = 'Torres y murallas');

INSERT INTO routes (name, description, duration, status)
SELECT 'Cáceres fuera de la muralla', 'Palacios, museos y el santuario de la patrona fuera del recinto amurallado.', '120 min', 'published'
WHERE NOT EXISTS (SELECT 1 FROM routes WHERE name = 'Cáceres fuera de la muralla');

-- Lugares nuevos. Los puntos de cada uno son los de su categoría.
INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Concatedral de Santa María', 'Templo gótico de la plaza de Santa María, con la estatua de San Pedro de Alcántara.', 'SANTAMARIA24', c.points, 39.474, -6.3706, 3
FROM routes r JOIN categories c ON c.name = 'Iglesia y convento'
WHERE r.name = 'Secretos de la Ciudad Monumental'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'SANTAMARIA24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Palacio de los Golfines de Abajo', 'Palacio gótico y plateresco donde se alojaron los Reyes Católicos.', 'GOLFINES24', c.points, 39.4738, -6.3702, 4
FROM routes r JOIN categories c ON c.name = 'Palacio y casa noble'
WHERE r.name = 'Secretos de la Ciudad Monumental'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'GOLFINES24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Iglesia de San Mateo', 'Iglesia levantada en la parte más alta de la ciudad.', 'SANMATEO24', c.points, 39.4724, -6.3693, 5
FROM routes r JOIN categories c ON c.name = 'Iglesia y convento'
WHERE r.name = 'Secretos de la Ciudad Monumental'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'SANMATEO24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Barrio de San Antonio', 'La antigua judería, de calles estrechas y casas encaladas.', 'SANANTONIO24', c.points, 39.4718, -6.369, 3
FROM routes r JOIN categories c ON c.name = 'Plaza y calle'
WHERE r.name = 'Cáceres de leyenda'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'SANANTONIO24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Casa de Toledo-Moctezuma', 'Casa ligada a los descendientes de una hija del emperador Moctezuma.', 'MOCTEZUMA24', c.points, 39.4744, -6.3693, 4
FROM routes r JOIN categories c ON c.name = 'Palacio y casa noble'
WHERE r.name = 'Cáceres de leyenda'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'MOCTEZUMA24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Museo de Cáceres', 'En el Palacio de las Veletas, con un aljibe árabe en su interior.', 'MUSEOCC24', c.points, 39.4727, -6.3696, 2
FROM routes r JOIN categories c ON c.name = 'Museo'
WHERE r.name = 'Pequeños exploradores'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'MUSEOCC24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Ermita de la Paz', 'Pequeña ermita barroca junto a la Torre de Bujaco.', 'ERMITAPAZ24', c.points, 39.4752, -6.3712, 3
FROM routes r JOIN categories c ON c.name = 'Iglesia y convento'
WHERE r.name = 'Pequeños exploradores'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'ERMITAPAZ24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Torre de Bujaco', 'Torre almohade de la Plaza Mayor, con vistas a toda la plaza.', 'BUJACO24', c.points, 39.4749, -6.3714, 1
FROM routes r JOIN categories c ON c.name = 'Monumento'
WHERE r.name = 'Torres y murallas'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'BUJACO24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Torre de las Cigüeñas', 'La única torre de la ciudad que conservó sus almenas.', 'CIGUENAS24', c.points, 39.4726, -6.3698, 2
FROM routes r JOIN categories c ON c.name = 'Monumento'
WHERE r.name = 'Torres y murallas'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'CIGUENAS24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Arco del Cristo', 'Antigua puerta romana de la muralla, también llamada Puerta de Coria.', 'ARCOCRISTO24', c.points, 39.4745, -6.3684, 3
FROM routes r JOIN categories c ON c.name = 'Monumento'
WHERE r.name = 'Torres y murallas'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'ARCOCRISTO24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Torre de los Pozos', 'Torre de la muralla con un mirador sobre la ribera.', 'TORREPOZOS24', c.points, 39.4722, -6.3688, 4
FROM routes r JOIN categories c ON c.name = 'Mirador'
WHERE r.name = 'Torres y murallas'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'TORREPOZOS24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Iglesia de Santiago', 'Iglesia del barrio de Santiago, junto al Palacio de Godoy.', 'SANTIAGO24', c.points, 39.4762, -6.3698, 1
FROM routes r JOIN categories c ON c.name = 'Iglesia y convento'
WHERE r.name = 'Cáceres fuera de la muralla'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'SANTIAGO24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Palacio de Godoy', 'Palacio renacentista con un balcón en esquina muy característico.', 'GODOY24', c.points, 39.4763, -6.3701, 2
FROM routes r JOIN categories c ON c.name = 'Palacio y casa noble'
WHERE r.name = 'Cáceres fuera de la muralla'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'GODOY24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Museo Helga de Alvear', 'Museo de arte contemporáneo junto a la Ciudad Monumental.', 'HELGA24', c.points, 39.4749, -6.3725, 3
FROM routes r JOIN categories c ON c.name = 'Museo'
WHERE r.name = 'Cáceres fuera de la muralla'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'HELGA24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Calle Pintores', 'Calle comercial que une la Plaza Mayor con el centro de la ciudad.', 'PINTORES24', c.points, 39.4762, -6.372, 4
FROM routes r JOIN categories c ON c.name = 'Plaza y calle'
WHERE r.name = 'Cáceres fuera de la muralla'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'PINTORES24');

INSERT INTO places (route_id, category_id, name, description, qr_code, points, latitude, longitude, order_index)
SELECT r.id, c.id, 'Santuario de la Virgen de la Montaña', 'Santuario de la patrona de Cáceres, con vistas a toda la ciudad.', 'MONTANA24', c.points, 39.464, -6.355, 5
FROM routes r JOIN categories c ON c.name = 'Mirador'
WHERE r.name = 'Cáceres fuera de la muralla'
  AND NOT EXISTS (SELECT 1 FROM places WHERE qr_code = 'MONTANA24');

-- Participantes de prueba
-- CaceresGO - datos de demostración: 15 participantes con sus visitas y rutas terminadas.
-- Ejecutar en phpMyAdmin con la base de datos seleccionada, en la pestaña SQL (sirve en XAMPP y en el hosting).
-- Antes tiene que estar la V7 (categorías y 21 lugares).
-- Las fechas se calculan desde el día en que se ejecuta, para que siempre haya clasificación del mes y de la semana.
-- Si se vuelve a ejecutar (por ejemplo, el día antes de la defensa), se borran solo las visitas de estas 15 personas y se crean de nuevo con fechas al día.
-- Son personas inventadas. Todas tienen la contraseña clave1234. La aplicación no envía correos.

SET NAMES utf8mb4;

-- 1. Participantes
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Cristina Álvarez Holguín', 'cristina.alvarez.holguin@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1995-03-14', 'Cáceres', TIMESTAMP(CURDATE() - INTERVAL 60 DAY, '17:54:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Lucía Fernández Gómez', 'luciafdezgomez@hotmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1998-07-22', 'Cáceres', TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '16:32:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Javier Martín Sánchez', 'javi.martin.sanchez@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1991-11-02', 'Badajoz', TIMESTAMP(CURDATE() - INTERVAL 31 DAY, '12:11:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('María José Pérez Durán', 'mariajo.perezduran@outlook.es', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1987-01-30', 'Mérida', TIMESTAMP(CURDATE() - INTERVAL 56 DAY, '16:40:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Alejandro Rodríguez Bravo', 'alex.rodriguezbravo@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '2000-05-09', 'Madrid', TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '21:11:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Carmen Sánchez Mateos', 'carmen.sanchezmateos@yahoo.es', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1979-09-17', 'Plasencia', TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '16:19:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('David González Ríos', 'dgonzalezrios@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1993-02-25', 'Sevilla', TIMESTAMP(CURDATE() - INTERVAL 30 DAY, '10:34:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Laura Jiménez Cortés', 'laura.jimenez.cortes@hotmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '2003-12-01', 'Cáceres', TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '18:25:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Pablo Moreno Galán', 'pablomorenogalan@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1996-06-12', 'Salamanca', TIMESTAMP(CURDATE() - INTERVAL 38 DAY, '19:47:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Elena Romero Castaño', 'elena.romero.castano@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1989-04-05', 'Trujillo', TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '19:10:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Sergio Navarro Pizarro', 'sergionavarropizarro@outlook.es', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1985-08-19', 'Navalmoral de la Mata', TIMESTAMP(CURDATE() - INTERVAL 64 DAY, '09:53:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Ana Belén Ruiz Calvo', 'anabelen.ruizcalvo@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1999-10-28', 'Cáceres', TIMESTAMP(CURDATE() - INTERVAL 28 DAY, '10:03:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Rubén Díaz Barrantes', 'ruben.diaz.barrantes@hotmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1997-03-03', 'Coria', TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '12:56:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Marta Hernández Ciudad', 'marta.hdez.ciudad@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '2001-07-07', 'Valencia', TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '18:01:00'));
INSERT IGNORE INTO users (name, email, password_hash, role, status, birth_date, city, created_at) VALUES ('Iván Muñoz Tejeda', 'ivan.munoz.tejeda@gmail.com', '$2y$10$asYUC0zmyEHJcZ8AXCMwXOEv8XysHwRyDjoMvk6tjqrq6Fs2Udguq', 'participant', 'active', '1994-01-21', 'Cáceres', TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:28:00'));

-- 2. Borro las visitas y rutas terminadas anteriores de estas personas para crearlas con fechas al día
DELETE FROM route_completions WHERE user_id IN (SELECT id FROM users WHERE email IN ('cristina.alvarez.holguin@gmail.com', 'luciafdezgomez@hotmail.com', 'javi.martin.sanchez@gmail.com', 'mariajo.perezduran@outlook.es', 'alex.rodriguezbravo@gmail.com', 'carmen.sanchezmateos@yahoo.es', 'dgonzalezrios@gmail.com', 'laura.jimenez.cortes@hotmail.com', 'pablomorenogalan@gmail.com', 'elena.romero.castano@gmail.com', 'sergionavarropizarro@outlook.es', 'anabelen.ruizcalvo@gmail.com', 'ruben.diaz.barrantes@hotmail.com', 'marta.hdez.ciudad@gmail.com', 'ivan.munoz.tejeda@gmail.com'));
DELETE FROM visits WHERE user_id IN (SELECT id FROM users WHERE email IN ('cristina.alvarez.holguin@gmail.com', 'luciafdezgomez@hotmail.com', 'javi.martin.sanchez@gmail.com', 'mariajo.perezduran@outlook.es', 'alex.rodriguezbravo@gmail.com', 'carmen.sanchezmateos@yahoo.es', 'dgonzalezrios@gmail.com', 'laura.jimenez.cortes@hotmail.com', 'pablomorenogalan@gmail.com', 'elena.romero.castano@gmail.com', 'sergionavarropizarro@outlook.es', 'anabelen.ruizcalvo@gmail.com', 'ruben.diaz.barrantes@hotmail.com', 'marta.hdez.ciudad@gmail.com', 'ivan.munoz.tejeda@gmail.com'));

-- 3. Lugares validados (los puntos son los de cada lugar)
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '14:10:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '14:30:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '14:45:00') FROM users u JOIN places p ON p.qr_code = 'SANTAMARIA24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '15:07:00') FROM users u JOIN places p ON p.qr_code = 'GOLFINES24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '15:23:00') FROM users u JOIN places p ON p.qr_code = 'SANMATEO24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '10:00:00') FROM users u JOIN places p ON p.qr_code = 'CASASOL24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '10:19:00') FROM users u JOIN places p ON p.qr_code = 'CARVAJAL24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '10:41:00') FROM users u JOIN places p ON p.qr_code = 'SANANTONIO24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '10:57:00') FROM users u JOIN places p ON p.qr_code = 'MOCTEZUMA24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 46 DAY, '14:00:00') FROM users u JOIN places p ON p.qr_code = 'SANJORGE24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 46 DAY, '14:16:00') FROM users u JOIN places p ON p.qr_code = 'MUSEOCC24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 46 DAY, '14:33:00') FROM users u JOIN places p ON p.qr_code = 'ERMITAPAZ24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '14:20:00') FROM users u JOIN places p ON p.qr_code = 'BUJACO24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '14:32:00') FROM users u JOIN places p ON p.qr_code = 'CIGUENAS24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '14:45:00') FROM users u JOIN places p ON p.qr_code = 'ARCOCRISTO24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '15:06:00') FROM users u JOIN places p ON p.qr_code = 'TORREPOZOS24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '13:00:00') FROM users u JOIN places p ON p.qr_code = 'SANTIAGO24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '13:16:00') FROM users u JOIN places p ON p.qr_code = 'GODOY24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '13:34:00') FROM users u JOIN places p ON p.qr_code = 'HELGA24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '13:47:00') FROM users u JOIN places p ON p.qr_code = 'PINTORES24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '13:59:00') FROM users u JOIN places p ON p.qr_code = 'MONTANA24' WHERE u.email = 'cristina.alvarez.holguin@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '10:10:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '10:25:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '10:37:00') FROM users u JOIN places p ON p.qr_code = 'SANTAMARIA24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '10:56:00') FROM users u JOIN places p ON p.qr_code = 'GOLFINES24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '11:14:00') FROM users u JOIN places p ON p.qr_code = 'SANMATEO24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '13:00:00') FROM users u JOIN places p ON p.qr_code = 'CASASOL24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '13:21:00') FROM users u JOIN places p ON p.qr_code = 'CARVAJAL24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '13:43:00') FROM users u JOIN places p ON p.qr_code = 'SANANTONIO24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '13:58:00') FROM users u JOIN places p ON p.qr_code = 'MOCTEZUMA24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 38 DAY, '12:20:00') FROM users u JOIN places p ON p.qr_code = 'SANJORGE24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '12:20:00') FROM users u JOIN places p ON p.qr_code = 'BUJACO24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '12:32:00') FROM users u JOIN places p ON p.qr_code = 'CIGUENAS24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '12:50:00') FROM users u JOIN places p ON p.qr_code = 'ARCOCRISTO24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '13:03:00') FROM users u JOIN places p ON p.qr_code = 'TORREPOZOS24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '11:00:00') FROM users u JOIN places p ON p.qr_code = 'SANTIAGO24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '11:12:00') FROM users u JOIN places p ON p.qr_code = 'GODOY24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '11:24:00') FROM users u JOIN places p ON p.qr_code = 'HELGA24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '11:43:00') FROM users u JOIN places p ON p.qr_code = 'PINTORES24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '12:02:00') FROM users u JOIN places p ON p.qr_code = 'MONTANA24' WHERE u.email = 'luciafdezgomez@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '15:40:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '15:55:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '16:14:00') FROM users u JOIN places p ON p.qr_code = 'SANTAMARIA24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '16:34:00') FROM users u JOIN places p ON p.qr_code = 'GOLFINES24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '16:49:00') FROM users u JOIN places p ON p.qr_code = 'SANMATEO24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '13:30:00') FROM users u JOIN places p ON p.qr_code = 'BUJACO24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '13:43:00') FROM users u JOIN places p ON p.qr_code = 'CIGUENAS24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '14:01:00') FROM users u JOIN places p ON p.qr_code = 'ARCOCRISTO24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '14:19:00') FROM users u JOIN places p ON p.qr_code = 'TORREPOZOS24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:20:00') FROM users u JOIN places p ON p.qr_code = 'SANTIAGO24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:41:00') FROM users u JOIN places p ON p.qr_code = 'GODOY24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:57:00') FROM users u JOIN places p ON p.qr_code = 'HELGA24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '11:09:00') FROM users u JOIN places p ON p.qr_code = 'PINTORES24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '11:24:00') FROM users u JOIN places p ON p.qr_code = 'MONTANA24' WHERE u.email = 'javi.martin.sanchez@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '13:40:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '14:02:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '14:23:00') FROM users u JOIN places p ON p.qr_code = 'SANTAMARIA24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '14:36:00') FROM users u JOIN places p ON p.qr_code = 'GOLFINES24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '14:48:00') FROM users u JOIN places p ON p.qr_code = 'SANMATEO24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 48 DAY, '11:30:00') FROM users u JOIN places p ON p.qr_code = 'CASASOL24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 48 DAY, '11:46:00') FROM users u JOIN places p ON p.qr_code = 'CARVAJAL24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 48 DAY, '11:58:00') FROM users u JOIN places p ON p.qr_code = 'SANANTONIO24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 48 DAY, '12:19:00') FROM users u JOIN places p ON p.qr_code = 'MOCTEZUMA24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '16:20:00') FROM users u JOIN places p ON p.qr_code = 'SANJORGE24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '16:38:00') FROM users u JOIN places p ON p.qr_code = 'MUSEOCC24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '16:51:00') FROM users u JOIN places p ON p.qr_code = 'ERMITAPAZ24' WHERE u.email = 'mariajo.perezduran@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '10:10:00') FROM users u JOIN places p ON p.qr_code = 'BUJACO24' WHERE u.email = 'alex.rodriguezbravo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '10:31:00') FROM users u JOIN places p ON p.qr_code = 'CIGUENAS24' WHERE u.email = 'alex.rodriguezbravo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '10:53:00') FROM users u JOIN places p ON p.qr_code = 'ARCOCRISTO24' WHERE u.email = 'alex.rodriguezbravo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '11:08:00') FROM users u JOIN places p ON p.qr_code = 'TORREPOZOS24' WHERE u.email = 'alex.rodriguezbravo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '14:20:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'alex.rodriguezbravo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '14:37:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'alex.rodriguezbravo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 18 DAY, '13:10:00') FROM users u JOIN places p ON p.qr_code = 'CASASOL24' WHERE u.email = 'carmen.sanchezmateos@yahoo.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 18 DAY, '13:31:00') FROM users u JOIN places p ON p.qr_code = 'CARVAJAL24' WHERE u.email = 'carmen.sanchezmateos@yahoo.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 18 DAY, '13:50:00') FROM users u JOIN places p ON p.qr_code = 'SANANTONIO24' WHERE u.email = 'carmen.sanchezmateos@yahoo.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 18 DAY, '14:11:00') FROM users u JOIN places p ON p.qr_code = 'MOCTEZUMA24' WHERE u.email = 'carmen.sanchezmateos@yahoo.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 9 DAY, '16:30:00') FROM users u JOIN places p ON p.qr_code = 'SANJORGE24' WHERE u.email = 'carmen.sanchezmateos@yahoo.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 9 DAY, '16:44:00') FROM users u JOIN places p ON p.qr_code = 'MUSEOCC24' WHERE u.email = 'carmen.sanchezmateos@yahoo.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 9 DAY, '17:06:00') FROM users u JOIN places p ON p.qr_code = 'ERMITAPAZ24' WHERE u.email = 'carmen.sanchezmateos@yahoo.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '12:10:00') FROM users u JOIN places p ON p.qr_code = 'SANTIAGO24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '12:31:00') FROM users u JOIN places p ON p.qr_code = 'GODOY24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '12:46:00') FROM users u JOIN places p ON p.qr_code = 'HELGA24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '13:01:00') FROM users u JOIN places p ON p.qr_code = 'PINTORES24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '13:15:00') FROM users u JOIN places p ON p.qr_code = 'MONTANA24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:10:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:32:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '14:50:00') FROM users u JOIN places p ON p.qr_code = 'SANTAMARIA24' WHERE u.email = 'dgonzalezrios@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '14:00:00') FROM users u JOIN places p ON p.qr_code = 'SANJORGE24' WHERE u.email = 'laura.jimenez.cortes@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '14:18:00') FROM users u JOIN places p ON p.qr_code = 'MUSEOCC24' WHERE u.email = 'laura.jimenez.cortes@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '14:30:00') FROM users u JOIN places p ON p.qr_code = 'ERMITAPAZ24' WHERE u.email = 'laura.jimenez.cortes@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '10:00:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'pablomorenogalan@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '10:20:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'pablomorenogalan@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '10:36:00') FROM users u JOIN places p ON p.qr_code = 'SANTAMARIA24' WHERE u.email = 'pablomorenogalan@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '10:51:00') FROM users u JOIN places p ON p.qr_code = 'GOLFINES24' WHERE u.email = 'pablomorenogalan@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '11:09:00') FROM users u JOIN places p ON p.qr_code = 'SANMATEO24' WHERE u.email = 'pablomorenogalan@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '13:40:00') FROM users u JOIN places p ON p.qr_code = 'CASASOL24' WHERE u.email = 'elena.romero.castano@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '13:59:00') FROM users u JOIN places p ON p.qr_code = 'CARVAJAL24' WHERE u.email = 'elena.romero.castano@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '14:15:00') FROM users u JOIN places p ON p.qr_code = 'SANANTONIO24' WHERE u.email = 'elena.romero.castano@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '14:35:00') FROM users u JOIN places p ON p.qr_code = 'MOCTEZUMA24' WHERE u.email = 'elena.romero.castano@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '15:00:00') FROM users u JOIN places p ON p.qr_code = 'BUJACO24' WHERE u.email = 'elena.romero.castano@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '15:14:00') FROM users u JOIN places p ON p.qr_code = 'CIGUENAS24' WHERE u.email = 'elena.romero.castano@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 58 DAY, '13:40:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'sergionavarropizarro@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 58 DAY, '14:02:00') FROM users u JOIN places p ON p.qr_code = 'PLAZA24' WHERE u.email = 'sergionavarropizarro@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '14:00:00') FROM users u JOIN places p ON p.qr_code = 'BUJACO24' WHERE u.email = 'sergionavarropizarro@outlook.es';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '11:10:00') FROM users u JOIN places p ON p.qr_code = 'SANJORGE24' WHERE u.email = 'anabelen.ruizcalvo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '11:22:00') FROM users u JOIN places p ON p.qr_code = 'MUSEOCC24' WHERE u.email = 'anabelen.ruizcalvo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '11:35:00') FROM users u JOIN places p ON p.qr_code = 'ERMITAPAZ24' WHERE u.email = 'anabelen.ruizcalvo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '13:30:00') FROM users u JOIN places p ON p.qr_code = 'CASASOL24' WHERE u.email = 'anabelen.ruizcalvo@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '10:00:00') FROM users u JOIN places p ON p.qr_code = 'BUJACO24' WHERE u.email = 'ruben.diaz.barrantes@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '10:14:00') FROM users u JOIN places p ON p.qr_code = 'CIGUENAS24' WHERE u.email = 'ruben.diaz.barrantes@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '10:30:00') FROM users u JOIN places p ON p.qr_code = 'ARCOCRISTO24' WHERE u.email = 'ruben.diaz.barrantes@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '10:47:00') FROM users u JOIN places p ON p.qr_code = 'TORREPOZOS24' WHERE u.email = 'ruben.diaz.barrantes@hotmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '14:10:00') FROM users u JOIN places p ON p.qr_code = 'SANTIAGO24' WHERE u.email = 'marta.hdez.ciudad@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '14:23:00') FROM users u JOIN places p ON p.qr_code = 'GODOY24' WHERE u.email = 'marta.hdez.ciudad@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '14:40:00') FROM users u JOIN places p ON p.qr_code = 'HELGA24' WHERE u.email = 'marta.hdez.ciudad@gmail.com';
INSERT IGNORE INTO visits (user_id, route_id, place_id, points, validated_at) SELECT u.id, p.route_id, p.id, p.points, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '13:20:00') FROM users u JOIN places p ON p.qr_code = 'ESTRELLA24' WHERE u.email = 'ivan.munoz.tejeda@gmail.com';

-- 4. Rutas terminadas: las que tienen validados todos sus lugares
INSERT IGNORE INTO route_completions (user_id, route_id, points, completed_at)
SELECT v.user_id, v.route_id, SUM(v.points), MAX(v.validated_at)
FROM visits v
JOIN users u ON u.id = v.user_id
WHERE u.email IN ('cristina.alvarez.holguin@gmail.com', 'luciafdezgomez@hotmail.com', 'javi.martin.sanchez@gmail.com', 'mariajo.perezduran@outlook.es', 'alex.rodriguezbravo@gmail.com', 'carmen.sanchezmateos@yahoo.es', 'dgonzalezrios@gmail.com', 'laura.jimenez.cortes@hotmail.com', 'pablomorenogalan@gmail.com', 'elena.romero.castano@gmail.com', 'sergionavarropizarro@outlook.es', 'anabelen.ruizcalvo@gmail.com', 'ruben.diaz.barrantes@hotmail.com', 'marta.hdez.ciudad@gmail.com', 'ivan.munoz.tejeda@gmail.com')
GROUP BY v.user_id, v.route_id
HAVING COUNT(*) = (SELECT COUNT(*) FROM places p WHERE p.route_id = v.route_id);
