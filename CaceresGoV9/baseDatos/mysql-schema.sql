-- CaceresGO - esquema MySQL
-- Importar en phpMyAdmin sin seleccionar ninguna base: crea la base caceresgo_v8 con sus tablas y datos de ejemplo.

CREATE DATABASE IF NOT EXISTS caceresgo_v8
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE caceresgo_v8;
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
