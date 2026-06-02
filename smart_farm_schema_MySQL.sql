
-- MySQL 8.0+ — disable FK checks so forward-referenced tables can be defined in any order
SET FOREIGN_KEY_CHECKS = 0;

-- Reset all tables so this init-and-seed script can be imported repeatedly.
DROP TABLE IF EXISTS
  tileMessages,
  cropAiPredictions,
  cropImages,
  cropSensorReadings,
  harvestRecords,
  powerOutputLogs,
  mqttHubAlerts,
  batteryLevels,
  solarReadings,
  chickenEggs,
  coopActivityLogs,
  coopCleaningLogs,
  feedRecords,
  animalHealthLogs,
  predatorLog,
  waterSensorReadings,
  waterDistributionNodes,
  cropPlantings,
  waterSources,
  chickens,
  coops,
  fields,
  devices,
  batteries,
  solarPanel,
  crops,
  users,
  farmZones,
  farms,
  tiles,
  roles;

CREATE TABLE roles (
    roleId      INT AUTO_INCREMENT PRIMARY KEY,
    roleName    VARCHAR(50) UNIQUE NOT NULL,
    description TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'User roles - manageable via website admin panel.';

CREATE TABLE tiles (
    tileId          INT AUTO_INCREMENT PRIMARY KEY,
    tileName        VARCHAR(50) UNIQUE NOT NULL,
    description     TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Functional tiles used to categorise farm zones.';

CREATE TABLE tileMessages (
    messageId INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    srcTile   VARCHAR(50) NOT NULL,
    destTile  VARCHAR(50) NOT NULL,
    msgType   VARCHAR(50) NOT NULL COMMENT 'Examples: power_relay, command, ack, status.',
    payload   JSON,
    sentAt    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Messages exchanged between tiles.';

CREATE TABLE farms (
    farmId      INT AUTO_INCREMENT PRIMARY KEY,
    farmName    VARCHAR(150) UNIQUE NOT NULL,
  description TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Farm or organisation records used to scope users and farm zones.';


/* ================================================================
   USER MANAGEMENT
   ================================================================ */

CREATE TABLE users (
    userId        INT AUTO_INCREMENT PRIMARY KEY,
    firstName     VARCHAR(75) NOT NULL,
    lastName      VARCHAR(75) NOT NULL,
    username      VARCHAR(50) UNIQUE NOT NULL,
    email         VARCHAR(150) UNIQUE NOT NULL,
    password      TEXT NOT NULL COMMENT 'Store an application-generated Argon2id or bcrypt hash. Never store plaintext passwords or raw SHA2 output.',
      roleId        INTEGER NOT NULL DEFAULT 1,
    farmId        INTEGER,
    institution   VARCHAR(150),
    isActive      BOOLEAN NOT NULL DEFAULT TRUE,
    createdAt     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedAt     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_users_role FOREIGN KEY (roleId) REFERENCES roles(roleId) ON DELETE RESTRICT,
    CONSTRAINT fk_users_farm FOREIGN KEY (farmId) REFERENCES farms(farmId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'All registered users. Role is managed via dropdown; farm assignment scopes which farm data a user can access.';


/* ================================================================
   FARM ZONES
   ================================================================ */

CREATE TABLE farmZones (
    farmZoneId  INT AUTO_INCREMENT PRIMARY KEY,
    farmId      INTEGER NOT NULL,
    zoneName    VARCHAR(100) NOT NULL,
    tileId      INTEGER NOT NULL,
    description TEXT,
    areaSqMeter NUMERIC(10, 2),
    createdAt   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_farmzones_farm FOREIGN KEY (farmId) REFERENCES farms(farmId) ON DELETE RESTRICT,
    CONSTRAINT fk_farmzones_tile FOREIGN KEY (tileId) REFERENCES tiles(tileId) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Physical sections registered to a specific farm. Every group links its data to a farm-scoped zone.';


/* ================================================================
   SOLAR ENERGY
   ================================================================ */

CREATE TABLE solarPanel (
    solarPanelId  INT AUTO_INCREMENT PRIMARY KEY,
    zoneId        INTEGER,
    panelName     VARCHAR(100) NOT NULL DEFAULT 'Main Solar Panel',
    capacityKW    NUMERIC(8, 3) NOT NULL,
    installedDate DATE,
    isActive      BOOLEAN NOT NULL DEFAULT TRUE,
    notes         TEXT,
    CONSTRAINT fk_solarpanel_zone FOREIGN KEY (zoneId) REFERENCES farmZones(farmZoneId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Single solar panel configuration record.';

CREATE TABLE solarReadings (
    solarReadingId   INT AUTO_INCREMENT PRIMARY KEY,
    solarPanelId     INTEGER NOT NULL,
    takenAt          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the solar reading was taken.',
    powerGeneratedKw NUMERIC(8, 3) NOT NULL,
    lightLevel       INTEGER NOT NULL,
    CONSTRAINT fk_solarreadings_panel FOREIGN KEY (solarPanelId) REFERENCES solarPanel(solarPanelId) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Generated power measurements from solar panels over time.';

CREATE TABLE batteries (
    batteryId     INT AUTO_INCREMENT PRIMARY KEY,
    zoneId        INTEGER,
    batteryName   VARCHAR(100) NOT NULL,
    maxKW         NUMERIC(8, 3) NOT NULL,
    installedDate DATE,
    isActive      BOOLEAN NOT NULL DEFAULT TRUE,
    notes         TEXT,
    CONSTRAINT chk_batteries_maxkw CHECK (maxKW >= 0),
    CONSTRAINT fk_batteries_zone FOREIGN KEY (zoneId) REFERENCES farmZones(farmZoneId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Battery banks assigned to the power generation group.';

CREATE TABLE batteryLevels (
    batteryLevelId      INT AUTO_INCREMENT PRIMARY KEY,
    batteryId           INTEGER NOT NULL,
    takenAt             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the battery level reading was taken.',
    batteryLevelPercent NUMERIC(5, 2) NOT NULL,
    notes               TEXT,
    CONSTRAINT chk_batterylevels_percent CHECK (batteryLevelPercent >= 0 AND batteryLevelPercent <= 100),
    CONSTRAINT fk_batterylevels_battery FOREIGN KEY (batteryId) REFERENCES batteries(batteryId) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Battery charge level readings captured over time.';

CREATE TABLE powerOutputLogs (
    powerOutputLogId INT AUTO_INCREMENT PRIMARY KEY,
    deviceId         INTEGER NOT NULL,
    batteryId        INTEGER,
    destinationZoneId INTEGER NOT NULL COMMENT 'Destination farm zone receiving the generated or stored power.',
  takenAt          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the power usage reading was taken.',
    powerUsageKw     NUMERIC(8, 3) NOT NULL,
    notes            TEXT,
    CONSTRAINT fk_poweroutput_device FOREIGN KEY (deviceId)    REFERENCES devices(deviceId)       ON DELETE CASCADE,
    CONSTRAINT fk_poweroutput_battery FOREIGN KEY (batteryId)  REFERENCES batteries(batteryId)    ON DELETE SET NULL,
    CONSTRAINT fk_poweroutput_destination_zone FOREIGN KEY (destinationZoneId) REFERENCES farmZones(farmZoneId) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Power dispatch measurements recorded by devices. A reading can optionally be associated with a battery bank and records the destination farm zone receiving the power.';


/* ================================================================
  CROP FARMING
  ================================================================ */

CREATE TABLE fields (
    fieldId   INT AUTO_INCREMENT PRIMARY KEY,
    zoneId    INTEGER,
    fieldName VARCHAR(100) NOT NULL,
    areaM2    NUMERIC(10, 2),
    soilType  VARCHAR(100),
    notes     TEXT,
    createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fields_zone FOREIGN KEY (zoneId) REFERENCES farmZones(farmZoneId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE crops (
    cropId             INT AUTO_INCREMENT PRIMARY KEY,
    commonName         VARCHAR(100) NOT NULL,
    scientificName     VARCHAR(150),
    variety            VARCHAR(100),
    growthDurationDays INTEGER,
    notes              TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE cropPlantings (
    cropPlantingId      INT AUTO_INCREMENT PRIMARY KEY,
    fieldId             INTEGER NOT NULL,
    cropId              INTEGER NOT NULL,
    cropStatus          ENUM('planted', 'growing', 'ready_to_harvest', 'harvested', 'failed') NOT NULL,
    plantedDate         DATE NOT NULL,
    expectedHarvestDate DATE,
    actualHarvestDate   DATE,
    notes               TEXT,
    createdAt           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_plantings_field  FOREIGN KEY (fieldId)      REFERENCES fields(fieldId)            ON DELETE CASCADE,
  CONSTRAINT fk_plantings_crop   FOREIGN KEY (cropId)       REFERENCES crops(cropId)              ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE harvestRecords (
    harvestRecordId INT AUTO_INCREMENT PRIMARY KEY,
    plantingId      INTEGER NOT NULL,
    harvestedAt     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    yieldKg         NUMERIC(10, 2),
    qualityGrade    VARCHAR(20),
    notes           TEXT,
    CONSTRAINT fk_harvest_planting FOREIGN KEY (plantingId)  REFERENCES cropPlantings(cropPlantingId) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE cropSensorReadings (
    cropSensorReadingId INT AUTO_INCREMENT PRIMARY KEY,
    plantingId          INTEGER NOT NULL,
    deviceId            INTEGER NOT NULL,
    sensorType          VARCHAR(50) NOT NULL,  -- moisture, temperature, humidity, EC, NPK
    value1              NUMERIC(12, 4) COMMENT 'First sensor value: moisture %, temperature °C, EC value, or N reading.',
    value2              NUMERIC(12, 4) COMMENT 'Second sensor value: humidity % or Phosphorus reading.',
    value3              NUMERIC(12, 4) COMMENT 'Third sensor value: Potassium reading (NPK sensor only).',
  takenAt             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the crop sensor reading was taken.',
    CONSTRAINT fk_cropreading_planting FOREIGN KEY (plantingId) REFERENCES cropPlantings(cropPlantingId) ON DELETE CASCADE,
    CONSTRAINT fk_cropreading_device   FOREIGN KEY (deviceId)   REFERENCES devices(deviceId)             ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Multi-value sensor readings for crop plantings from moisture, temperature, EC, and NPK sensors.';

CREATE TABLE cropImages (
    cropImageId INT AUTO_INCREMENT PRIMARY KEY,
    plantingId  INTEGER NOT NULL,
    deviceId    INTEGER NOT NULL,
    imageData   LONGBLOB NOT NULL,
    takenAt     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the crop image was taken.',
    CONSTRAINT fk_cropimage_planting FOREIGN KEY (plantingId) REFERENCES cropPlantings(cropPlantingId) ON DELETE CASCADE,
    CONSTRAINT fk_cropimage_device   FOREIGN KEY (deviceId)   REFERENCES devices(deviceId)             ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Binary images captured for crop plantings by monitoring devices.';

CREATE TABLE cropAiPredictions (
    cropAiPredictionId INT AUTO_INCREMENT PRIMARY KEY,
    imageId            INTEGER NOT NULL,
    diseaseName        VARCHAR(150),
    confidenceScore    NUMERIC(5, 4),
    status             VARCHAR(20) NOT NULL CHECK (status IN ('healthy', 'unhealthy')),
    createdAt          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_crop_ai_image FOREIGN KEY (imageId) REFERENCES cropImages(cropImageId) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'AI disease detection results per crop image.';


/* ================================================================
   CHICKEN COOP
   ================================================================ */

CREATE TABLE coops (
    coopId    INT AUTO_INCREMENT PRIMARY KEY,
    zoneId    INTEGER,
    coopName  VARCHAR(100) NOT NULL,
    capacity  INTEGER NOT NULL,
    notes     TEXT,
  doorOpen  TIME,
  doorClose TIME,
  reminderDate DATETIME,
  reminderPeriod INTEGER,
    createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_coops_zone FOREIGN KEY (zoneId) REFERENCES farmZones(farmZoneId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE chickens (
    rfid         VARCHAR(100) PRIMARY KEY,  
    coopId       INTEGER,
    chickenName  VARCHAR(100),
    gender       VARCHAR(10),
    dateOfBirth  DATE,
    species      VARCHAR(100),
    weightKg     NUMERIC(6, 3),
  imageData    LONGBLOB,
    registerDate DATE NOT NULL DEFAULT (CURRENT_DATE),
    notes        TEXT,
    CONSTRAINT fk_chickens_coop FOREIGN KEY (coopId) REFERENCES coops(coopId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Individual RFID-tagged chickens. RFID tag is the primary key.';

-- Egg production per individual chicken (from chicken group schema)
CREATE TABLE chickenEggs (
    chickenEggId INT AUTO_INCREMENT PRIMARY KEY,
    rfid         VARCHAR(100) NOT NULL,
    recordedAt   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    eggCount     INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT fk_chickeneggs_rfid FOREIGN KEY (rfid) REFERENCES chickens(rfid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Egg production records per individual chicken.';

-- Unified coop activity logging for chicken movement and door events
CREATE TABLE coopActivityLogs (
    coopActivityLogId INT AUTO_INCREMENT PRIMARY KEY,
    coopId            INTEGER,
    rfid              VARCHAR(100),
    deviceId          INTEGER NOT NULL,
    eventType         ENUM('movement', 'door_open', 'door_close') NOT NULL,
    takenAt           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the coop activity event was detected.',
    movement          VARCHAR(255),
    notes             TEXT,
    CONSTRAINT fk_coopactivity_coop   FOREIGN KEY (coopId)   REFERENCES coops(coopId)     ON DELETE SET NULL,
    CONSTRAINT fk_coopactivity_rfid   FOREIGN KEY (rfid)     REFERENCES chickens(rfid)    ON DELETE SET NULL,
    CONSTRAINT fk_coopactivity_device FOREIGN KEY (deviceId) REFERENCES devices(deviceId) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Unified coop activity log for chicken movement and door events.';

-- Coop cleaning schedule and logs (from chicken group schema)
CREATE TABLE coopCleaningLogs (
    coopCleaningLogId INT AUTO_INCREMENT PRIMARY KEY,
    coopId            INTEGER,
    lastCleaned       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    nextCleanDue      DATETIME,  -- calculated from cleaning timer/interval
    weightKg          NUMERIC(8, 2),
    notes             TEXT,
  CONSTRAINT fk_coopcleaning_coop FOREIGN KEY (coopId) REFERENCES coops(coopId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Cleaning schedule and completion logs per coop, including recorded cleaning weight.';

-- Feed records (kept from v2)
CREATE TABLE feedRecords (
    feedRecordId INT AUTO_INCREMENT PRIMARY KEY,
    coopId       INTEGER NOT NULL,
    feedType     VARCHAR(100),
    quantityKg   NUMERIC(8, 2) NOT NULL,
    recordedAt   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes        TEXT,
  CONSTRAINT fk_feedrecords_coop FOREIGN KEY (coopId) REFERENCES coops(coopId) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Health logs (kept from v2, now per chicken rather than per flock)
CREATE TABLE animalHealthLogs (
    animalHealthLogId INT AUTO_INCREMENT PRIMARY KEY,
    rfid              VARCHAR(100),
    observation       TEXT NOT NULL,
    actionTaken       TEXT,
    recordedAt        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_healthlogs_rfid FOREIGN KEY (rfid) REFERENCES chickens(rfid) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Predator detections captured for the coop
CREATE TABLE predatorLog (
    predatorLogId   INT AUTO_INCREMENT PRIMARY KEY,
    coopId          INTEGER,
    deviceId        INTEGER,
    timeOfDetection DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the predator was detected.',
    confidenceScore NUMERIC(5, 4),
    predatorType    VARCHAR(100) NOT NULL,
    imageData       LONGBLOB,
    CONSTRAINT fk_predatorlog_coop   FOREIGN KEY (coopId)   REFERENCES coops(coopId)     ON DELETE SET NULL,
    CONSTRAINT fk_predatorlog_device FOREIGN KEY (deviceId) REFERENCES devices(deviceId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Predator detections for coops with confidence scores and captured image evidence.';


/* ================================================================
   SECTION 8: WATER DISTRIBUTION
   ================================================================ */

CREATE TABLE waterSources (
    waterSourceId     INT AUTO_INCREMENT PRIMARY KEY,
    zoneId            INTEGER,
    waterSourceType   ENUM('borehole', 'reservoir', 'rainwater', 'municipal', 'river') NOT NULL,
    waterSourceName   VARCHAR(100) NOT NULL,
    capacityLiters    NUMERIC(12, 2),
    notes             TEXT,
    createdAt         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_watersources_zone FOREIGN KEY (zoneId) REFERENCES farmZones(farmZoneId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE waterDistributionNodes (
    nodeId    INT AUTO_INCREMENT PRIMARY KEY,
    zoneId    INTEGER,
    sourceId  INTEGER,
    nodeName  VARCHAR(100) NOT NULL,
    nodeType  VARCHAR(50),  -- valve, pump, trough, pipe junction
    notes     TEXT,
    createdAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_waternode_zone   FOREIGN KEY (zoneId)   REFERENCES farmZones(farmZoneId)        ON DELETE SET NULL,
    CONSTRAINT fk_waternode_source FOREIGN KEY (sourceId) REFERENCES waterSources(waterSourceId)  ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Points in the water network: valves, pumps, troughs.';

CREATE TABLE waterSensorReadings (
    waterSensorReadingId INT AUTO_INCREMENT PRIMARY KEY,
    nodeId               INTEGER NOT NULL,
    deviceId             INTEGER NOT NULL,
  takenAt              DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp when the water sensor reading was taken.',
    depthLevelCm         NUMERIC(10, 2) NOT NULL COMMENT 'Water depth level in centimeters.',
    turbidityNtu         INTEGER NOT NULL COMMENT 'Measured turbidity in NTU. Typical operating range is 1-600 NTU, but higher values are allowed.',
    flowRateValve1MlPerSec NUMERIC(12, 3) NOT NULL COMMENT 'Valve 1 flow rate in milliliters per second.',
    flowRateValve2MlPerSec NUMERIC(12, 3) NOT NULL COMMENT 'Valve 2 flow rate in milliliters per second.',
    notes                TEXT,
    CONSTRAINT chk_watersensor_depth     CHECK (depthLevelCm >= 0),
    CONSTRAINT chk_watersensor_turbidity CHECK (turbidityNtu >= 0),
    CONSTRAINT chk_watersensor_flow_valve1 CHECK (flowRateValve1MlPerSec >= 0),
    CONSTRAINT chk_watersensor_flow_valve2 CHECK (flowRateValve2MlPerSec >= 0),
    CONSTRAINT fk_watersensor_node       FOREIGN KEY (nodeId)   REFERENCES waterDistributionNodes(nodeId) ON DELETE CASCADE,
    CONSTRAINT fk_watersensor_device     FOREIGN KEY (deviceId) REFERENCES devices(deviceId)              ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Water sensor readings for depth level, turbidity, and per-valve flow rates.';


/* ================================================================
   SHARED DEVICES TABLE
   ================================================================ */

CREATE TABLE devices (
    deviceId        INT AUTO_INCREMENT PRIMARY KEY,
    zoneId          INTEGER,
    deviceName      VARCHAR(100) NOT NULL,
    deviceType      VARCHAR(100),  -- camera, moisture, temp_humidity, EC, NPK, ESP32, etc.
    location        VARCHAR(150),
    protocol        ENUM('LoRa', 'Meshtastic', 'WiFi', 'Ethernet', 'Other'),
    status          ENUM('online', 'offline', 'maintenance'),
    macAddress      VARCHAR(50),
    firmwareVersion VARCHAR(50),
    lastSeen        DATETIME,
    notes           TEXT,
    createdAt       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_devices_zone FOREIGN KEY (zoneId) REFERENCES farmZones(farmZoneId) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'All IoT devices from every group. Multiple devices can belong to the same farm zone for different sensing and control use cases.';

CREATE TABLE mqttHubAlerts (
    mqttHubAlertId INT AUTO_INCREMENT PRIMARY KEY,
    severity       VARCHAR(30),
    tileGroup      VARCHAR(100),
    alertMessage   TEXT,
    payloadJson    JSON NOT NULL COMMENT 'Full MQTT payload stored for traceability and later reprocessing.',
    receivedAt     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT = 'Alerts received through MQTT and processed by the hub alert handler.';


/* ================================================================
   INDEXES
   ================================================================ */

/* Users */
CREATE INDEX idx_users_username    ON users(username);
CREATE INDEX idx_users_email       ON users(email);
CREATE INDEX idx_users_farm        ON users(farmId);
CREATE INDEX idx_users_institution ON users(institution);

/* Farms */
CREATE INDEX idx_farmzones_farm    ON farmZones(farmId);

/* Solar */
CREATE INDEX idx_solar_readings_panel ON solarReadings(solarPanelId);
CREATE INDEX idx_solar_readings_time  ON solarReadings(takenAt DESC);
CREATE INDEX idx_batteries_zone       ON batteries(zoneId);
CREATE INDEX idx_battery_levels_time  ON batteryLevels(batteryId, takenAt DESC);
CREATE INDEX idx_power_output_dev     ON powerOutputLogs(deviceId, takenAt DESC);
CREATE INDEX idx_power_output_battery ON powerOutputLogs(batteryId, takenAt DESC);
CREATE INDEX idx_power_output_destination_zone ON powerOutputLogs(destinationZoneId, takenAt DESC);

/* Crops */
CREATE INDEX idx_plantings_field    ON cropPlantings(fieldId);
CREATE INDEX idx_plantings_status   ON cropPlantings(cropStatus);
CREATE INDEX idx_harvest_planting   ON harvestRecords(plantingId);
CREATE INDEX idx_crop_readings_planting ON cropSensorReadings(plantingId, takenAt DESC);
CREATE INDEX idx_crop_readings_dev      ON cropSensorReadings(deviceId, takenAt DESC);
CREATE INDEX idx_crop_images_planting   ON cropImages(plantingId, takenAt DESC);
CREATE INDEX idx_crop_images_dev        ON cropImages(deviceId, takenAt DESC);
CREATE INDEX idx_crop_ai_image          ON cropAiPredictions(imageId);

/* Chickens */
CREATE INDEX idx_eggs_rfid_time     ON chickenEggs(rfid, recordedAt DESC);
CREATE INDEX idx_coop_activity_dev  ON coopActivityLogs(deviceId, takenAt DESC);
CREATE INDEX idx_coop_activity_rfid ON coopActivityLogs(rfid, takenAt DESC);
CREATE INDEX idx_coop_activity_coop ON coopActivityLogs(coopId, takenAt DESC);
CREATE INDEX idx_predator_log_coop  ON predatorLog(coopId, timeOfDetection DESC);
CREATE INDEX idx_predator_log_device ON predatorLog(deviceId, timeOfDetection DESC);

/* Water */
CREATE INDEX idx_water_readings_dev  ON waterSensorReadings(deviceId, takenAt DESC);
CREATE INDEX idx_water_readings_node ON waterSensorReadings(nodeId, takenAt DESC);

/* Devices */
CREATE INDEX idx_devices_zone       ON devices(zoneId);
CREATE INDEX idx_devices_type       ON devices(deviceType);

/* MQTT */
CREATE INDEX idx_mqtthubalerts_received_at ON mqttHubAlerts(receivedAt DESC);
CREATE INDEX idx_mqtthubalerts_severity    ON mqttHubAlerts(severity, receivedAt DESC);
CREATE INDEX idx_mqtthubalerts_tilegroup   ON mqttHubAlerts(tileGroup, receivedAt DESC);

/* AI / Detection */
CREATE INDEX idx_predator_log_time ON predatorLog(timeOfDetection DESC);


/* ================================================================
  INSERT/UPDATE ZONE ENFORCEMENT
  ================================================================ */

DELIMITER $$

DROP FUNCTION IF EXISTS fn_zone_has_tile $$
CREATE FUNCTION fn_zone_has_tile(
  requested_zone_id INT,
  expected_tile_name VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
)
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE zone_match INT DEFAULT 0;

  IF requested_zone_id IS NULL THEN
    RETURN 1;
  END IF;

  SELECT COUNT(*)
    INTO zone_match
    FROM farmZones z
    JOIN tiles t ON t.tileId = z.tileId
   WHERE z.farmZoneId = requested_zone_id
     AND t.tileName COLLATE utf8mb4_unicode_ci = expected_tile_name;

  RETURN IF(zone_match > 0, 1, 0);
END $$

DROP FUNCTION IF EXISTS fn_zone_farm_id $$
CREATE FUNCTION fn_zone_farm_id(requested_zone_id INT)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE zone_farm_id INT DEFAULT NULL;

  IF requested_zone_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT farmId
    INTO zone_farm_id
    FROM farmZones
   WHERE farmZoneId = requested_zone_id;

  RETURN zone_farm_id;
END $$

DROP FUNCTION IF EXISTS fn_same_farm_for_zones $$
CREATE FUNCTION fn_same_farm_for_zones(first_zone_id INT, second_zone_id INT)
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE first_farm_id INT DEFAULT NULL;
  DECLARE second_farm_id INT DEFAULT NULL;

  SET first_farm_id = fn_zone_farm_id(first_zone_id);
  SET second_farm_id = fn_zone_farm_id(second_zone_id);

  IF first_farm_id IS NULL OR second_farm_id IS NULL OR first_farm_id <> second_farm_id THEN
    RETURN 0;
  END IF;

  RETURN 1;
END $$

DROP FUNCTION IF EXISTS fn_same_zone_has_tile $$
CREATE FUNCTION fn_same_zone_has_tile(
  first_zone_id INT,
  second_zone_id INT,
  expected_tile_name VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
)
RETURNS TINYINT
READS SQL DATA
BEGIN
  IF first_zone_id IS NULL
     OR second_zone_id IS NULL
     OR first_zone_id <> second_zone_id
     OR fn_same_farm_for_zones(first_zone_id, second_zone_id) = 0 THEN
    RETURN 0;
  END IF;

  RETURN fn_zone_has_tile(first_zone_id, expected_tile_name);
END $$

DROP TRIGGER IF EXISTS trg_power_output_logs_validate_device $$
CREATE TRIGGER trg_power_output_logs_validate_device
BEFORE INSERT ON powerOutputLogs
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;
  DECLARE device_zone_id INT DEFAULT NULL;
  DECLARE battery_zone_id INT DEFAULT NULL;

  IF NEW.deviceId IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'powerOutputLogs requires a deviceId.';
  END IF;

  SELECT zoneId
    INTO device_zone_id
    FROM devices
   WHERE deviceId = NEW.deviceId;

  IF fn_same_farm_for_zones(device_zone_id, NEW.destinationZoneId) = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'powerOutputLogs device and destination zone must belong to the same farm.';
  END IF;

  IF NEW.batteryId IS NOT NULL THEN
    SELECT zoneId
      INTO battery_zone_id
      FROM batteries
     WHERE batteryId = NEW.batteryId;

    SELECT COUNT(*)
      INTO valid_match
      FROM devices d
      JOIN farmZones dz ON dz.farmZoneId = d.zoneId
      JOIN tiles dt ON dt.tileId = dz.tileId
      JOIN batteries b ON b.batteryId = NEW.batteryId
      JOIN farmZones bz ON bz.farmZoneId = b.zoneId
      JOIN tiles bt ON bt.tileId = bz.tileId
     WHERE d.deviceId = NEW.deviceId
       AND d.zoneId = b.zoneId
       AND dt.tileName = 'Power Tile'
       AND bt.tileName = 'Power Tile';

    IF valid_match > 0 AND fn_same_farm_for_zones(battery_zone_id, NEW.destinationZoneId) = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'powerOutputLogs battery and destination zone must belong to the same farm.';
    END IF;
  ELSE
    SELECT COUNT(*)
      INTO valid_match
      FROM devices d
      JOIN farmZones dz ON dz.farmZoneId = d.zoneId
      JOIN tiles dt ON dt.tileId = dz.tileId
     WHERE d.deviceId = NEW.deviceId
       AND dt.tileName = 'Power Tile';
  END IF;

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the correct Power Tile zone for powerOutputLogs.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_sensor_readings_validate_device $$
CREATE TRIGGER trg_crop_sensor_readings_validate_device
BEFORE INSERT ON cropSensorReadings
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;

  SELECT COUNT(*)
    INTO valid_match
    FROM devices d
    JOIN farmZones dz ON dz.farmZoneId = d.zoneId
    JOIN tiles dt ON dt.tileId = dz.tileId
    JOIN cropPlantings cp ON cp.cropPlantingId = NEW.plantingId
    JOIN fields f ON f.fieldId = cp.fieldId
    JOIN farmZones fz ON fz.farmZoneId = f.zoneId
    JOIN tiles ft ON ft.tileId = fz.tileId
   WHERE d.deviceId = NEW.deviceId
     AND d.zoneId = f.zoneId
     AND dt.tileName = 'Crop Tile'
     AND ft.tileName = 'Crop Tile';

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Crop Tile zone as the planting field.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_images_validate_device $$
CREATE TRIGGER trg_crop_images_validate_device
BEFORE INSERT ON cropImages
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;

  SELECT COUNT(*)
    INTO valid_match
    FROM devices d
    JOIN farmZones dz ON dz.farmZoneId = d.zoneId
    JOIN tiles dt ON dt.tileId = dz.tileId
    JOIN cropPlantings cp ON cp.cropPlantingId = NEW.plantingId
    JOIN fields f ON f.fieldId = cp.fieldId
    JOIN farmZones fz ON fz.farmZoneId = f.zoneId
    JOIN tiles ft ON ft.tileId = fz.tileId
   WHERE d.deviceId = NEW.deviceId
     AND d.zoneId = f.zoneId
     AND dt.tileName = 'Crop Tile'
     AND ft.tileName = 'Crop Tile';

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Crop Tile zone as the planting field.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_coop_activity_logs_validate_device $$
CREATE TRIGGER trg_coop_activity_logs_validate_device
BEFORE INSERT ON coopActivityLogs
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;
  DECLARE coop_zone_id INT DEFAULT NULL;
  DECLARE device_zone_id INT DEFAULT NULL;
  DECLARE chicken_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'coopActivityLogs requires coopId when deviceId is provided.';
  END IF;

  SELECT zoneId
    INTO coop_zone_id
    FROM coops
   WHERE coopId = NEW.coopId;

  IF coop_zone_id IS NULL OR fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'coopActivityLogs.coopId must reference a Chicken Coop Tile zone.';
  END IF;

  SELECT zoneId
    INTO device_zone_id
    FROM devices
   WHERE deviceId = NEW.deviceId;

  SET valid_match = fn_same_zone_has_tile(device_zone_id, coop_zone_id, 'Chicken Coop Tile');

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Chicken Coop Tile zone as the coop.';
  END IF;

  IF NEW.rfid IS NOT NULL THEN
    SELECT c.zoneId
      INTO chicken_zone_id
      FROM chickens ch
      LEFT JOIN coops c ON c.coopId = ch.coopId
     WHERE ch.rfid = NEW.rfid;

    IF fn_same_zone_has_tile(chicken_zone_id, coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RFID chicken record must belong to the same Chicken Coop Tile zone as the coop.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_predator_log_validate_device $$
CREATE TRIGGER trg_predator_log_validate_device
BEFORE INSERT ON predatorLog
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;
  DECLARE coop_zone_id INT DEFAULT NULL;
  DECLARE device_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NOT NULL THEN
    SELECT zoneId
      INTO coop_zone_id
      FROM coops
     WHERE coopId = NEW.coopId;

    IF coop_zone_id IS NULL OR fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'predatorLog.coopId must reference a Chicken Coop Tile zone.';
    END IF;
  END IF;

  IF NEW.deviceId IS NOT NULL THEN
    IF NEW.coopId IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'predatorLog requires coopId when deviceId is provided.';
    END IF;

    SELECT zoneId
      INTO device_zone_id
      FROM devices
     WHERE deviceId = NEW.deviceId;

    SET valid_match = fn_same_zone_has_tile(device_zone_id, coop_zone_id, 'Chicken Coop Tile');

    IF valid_match = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Device must belong to the same Chicken Coop Tile zone as the coop.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_water_sensor_readings_validate_device $$
CREATE TRIGGER trg_water_sensor_readings_validate_device
BEFORE INSERT ON waterSensorReadings
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;

  SELECT COUNT(*)
    INTO valid_match
    FROM devices d
    JOIN farmZones dz ON dz.farmZoneId = d.zoneId
    JOIN tiles dt ON dt.tileId = dz.tileId
    JOIN waterDistributionNodes n ON n.nodeId = NEW.nodeId
    JOIN farmZones nz ON nz.farmZoneId = n.zoneId
    JOIN tiles nt ON nt.tileId = nz.tileId
   WHERE d.deviceId = NEW.deviceId
     AND d.zoneId = n.zoneId
     AND dt.tileName = 'Water Distribution Tile'
     AND nt.tileName = 'Water Distribution Tile';

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Water Distribution Tile zone as the node.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_power_output_logs_validate_device_update $$
CREATE TRIGGER trg_power_output_logs_validate_device_update
BEFORE UPDATE ON powerOutputLogs
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;
  DECLARE device_zone_id INT DEFAULT NULL;
  DECLARE battery_zone_id INT DEFAULT NULL;

  IF NEW.deviceId IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'powerOutputLogs requires a deviceId.';
  END IF;

  SELECT zoneId
    INTO device_zone_id
    FROM devices
   WHERE deviceId = NEW.deviceId;

  IF fn_same_farm_for_zones(device_zone_id, NEW.destinationZoneId) = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'powerOutputLogs device and destination zone must belong to the same farm.';
  END IF;

  IF NEW.batteryId IS NOT NULL THEN
    SELECT zoneId
      INTO battery_zone_id
      FROM batteries
     WHERE batteryId = NEW.batteryId;

    SELECT COUNT(*)
      INTO valid_match
      FROM devices d
      JOIN farmZones dz ON dz.farmZoneId = d.zoneId
      JOIN tiles dt ON dt.tileId = dz.tileId
      JOIN batteries b ON b.batteryId = NEW.batteryId
      JOIN farmZones bz ON bz.farmZoneId = b.zoneId
      JOIN tiles bt ON bt.tileId = bz.tileId
     WHERE d.deviceId = NEW.deviceId
       AND d.zoneId = b.zoneId
       AND dt.tileName = 'Power Tile'
       AND bt.tileName = 'Power Tile';

    IF valid_match > 0 AND fn_same_farm_for_zones(battery_zone_id, NEW.destinationZoneId) = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'powerOutputLogs battery and destination zone must belong to the same farm.';
    END IF;
  ELSE
    SELECT COUNT(*)
      INTO valid_match
      FROM devices d
      JOIN farmZones dz ON dz.farmZoneId = d.zoneId
      JOIN tiles dt ON dt.tileId = dz.tileId
     WHERE d.deviceId = NEW.deviceId
       AND dt.tileName = 'Power Tile';
  END IF;

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the correct Power Tile zone for powerOutputLogs.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_sensor_readings_validate_device_update $$
CREATE TRIGGER trg_crop_sensor_readings_validate_device_update
BEFORE UPDATE ON cropSensorReadings
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;

  SELECT COUNT(*)
    INTO valid_match
    FROM devices d
    JOIN farmZones dz ON dz.farmZoneId = d.zoneId
    JOIN tiles dt ON dt.tileId = dz.tileId
    JOIN cropPlantings cp ON cp.cropPlantingId = NEW.plantingId
    JOIN fields f ON f.fieldId = cp.fieldId
    JOIN farmZones fz ON fz.farmZoneId = f.zoneId
    JOIN tiles ft ON ft.tileId = fz.tileId
   WHERE d.deviceId = NEW.deviceId
     AND d.zoneId = f.zoneId
     AND dt.tileName = 'Crop Tile'
     AND ft.tileName = 'Crop Tile';

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Crop Tile zone as the planting field.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_images_validate_device_update $$
CREATE TRIGGER trg_crop_images_validate_device_update
BEFORE UPDATE ON cropImages
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;

  SELECT COUNT(*)
    INTO valid_match
    FROM devices d
    JOIN farmZones dz ON dz.farmZoneId = d.zoneId
    JOIN tiles dt ON dt.tileId = dz.tileId
    JOIN cropPlantings cp ON cp.cropPlantingId = NEW.plantingId
    JOIN fields f ON f.fieldId = cp.fieldId
    JOIN farmZones fz ON fz.farmZoneId = f.zoneId
    JOIN tiles ft ON ft.tileId = fz.tileId
   WHERE d.deviceId = NEW.deviceId
     AND d.zoneId = f.zoneId
     AND dt.tileName = 'Crop Tile'
     AND ft.tileName = 'Crop Tile';

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Crop Tile zone as the planting field.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_coop_activity_logs_validate_device_update $$
CREATE TRIGGER trg_coop_activity_logs_validate_device_update
BEFORE UPDATE ON coopActivityLogs
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;
  DECLARE coop_zone_id INT DEFAULT NULL;
  DECLARE device_zone_id INT DEFAULT NULL;
  DECLARE chicken_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'coopActivityLogs requires coopId when deviceId is provided.';
  END IF;

  SELECT zoneId
    INTO coop_zone_id
    FROM coops
   WHERE coopId = NEW.coopId;

  IF coop_zone_id IS NULL OR fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'coopActivityLogs.coopId must reference a Chicken Coop Tile zone.';
  END IF;

  SELECT zoneId
    INTO device_zone_id
    FROM devices
   WHERE deviceId = NEW.deviceId;

  SET valid_match = fn_same_zone_has_tile(device_zone_id, coop_zone_id, 'Chicken Coop Tile');

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Chicken Coop Tile zone as the coop.';
  END IF;

  IF NEW.rfid IS NOT NULL THEN
    SELECT c.zoneId
      INTO chicken_zone_id
      FROM chickens ch
      LEFT JOIN coops c ON c.coopId = ch.coopId
     WHERE ch.rfid = NEW.rfid;

    IF fn_same_zone_has_tile(chicken_zone_id, coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RFID chicken record must belong to the same Chicken Coop Tile zone as the coop.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_predator_log_validate_device_update $$
CREATE TRIGGER trg_predator_log_validate_device_update
BEFORE UPDATE ON predatorLog
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;
  DECLARE coop_zone_id INT DEFAULT NULL;
  DECLARE device_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NOT NULL THEN
    SELECT zoneId
      INTO coop_zone_id
      FROM coops
     WHERE coopId = NEW.coopId;

    IF coop_zone_id IS NULL OR fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'predatorLog.coopId must reference a Chicken Coop Tile zone.';
    END IF;
  END IF;

  IF NEW.deviceId IS NOT NULL THEN
    IF NEW.coopId IS NULL THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'predatorLog requires coopId when deviceId is provided.';
    END IF;

    SELECT zoneId
      INTO device_zone_id
      FROM devices
     WHERE deviceId = NEW.deviceId;

    SET valid_match = fn_same_zone_has_tile(device_zone_id, coop_zone_id, 'Chicken Coop Tile');

    IF valid_match = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Device must belong to the same Chicken Coop Tile zone as the coop.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_water_sensor_readings_validate_device_update $$
CREATE TRIGGER trg_water_sensor_readings_validate_device_update
BEFORE UPDATE ON waterSensorReadings
FOR EACH ROW
BEGIN
  DECLARE valid_match INT DEFAULT 0;

  SELECT COUNT(*)
    INTO valid_match
    FROM devices d
    JOIN farmZones dz ON dz.farmZoneId = d.zoneId
    JOIN tiles dt ON dt.tileId = dz.tileId
    JOIN waterDistributionNodes n ON n.nodeId = NEW.nodeId
    JOIN farmZones nz ON nz.farmZoneId = n.zoneId
    JOIN tiles nt ON nt.tileId = nz.tileId
   WHERE d.deviceId = NEW.deviceId
     AND d.zoneId = n.zoneId
     AND dt.tileName = 'Water Distribution Tile'
     AND nt.tileName = 'Water Distribution Tile';

  IF valid_match = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Device must belong to the same Water Distribution Tile zone as the node.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_solar_panel_validate_zone $$
CREATE TRIGGER trg_solar_panel_validate_zone
BEFORE INSERT ON solarPanel
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'solarPanel.zoneId must reference a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_solar_panel_validate_zone_update $$
CREATE TRIGGER trg_solar_panel_validate_zone_update
BEFORE UPDATE ON solarPanel
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'solarPanel.zoneId must reference a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_solar_readings_validate_zone $$
CREATE TRIGGER trg_solar_readings_validate_zone
BEFORE INSERT ON solarReadings
FOR EACH ROW
BEGIN
  DECLARE panel_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO panel_zone_id
    FROM solarPanel
   WHERE solarPanelId = NEW.solarPanelId;

  IF panel_zone_id IS NOT NULL AND fn_zone_has_tile(panel_zone_id, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'solarReadings.solarPanelId must reference a solar panel in a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_solar_readings_validate_zone_update $$
CREATE TRIGGER trg_solar_readings_validate_zone_update
BEFORE UPDATE ON solarReadings
FOR EACH ROW
BEGIN
  DECLARE panel_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO panel_zone_id
    FROM solarPanel
   WHERE solarPanelId = NEW.solarPanelId;

  IF panel_zone_id IS NOT NULL AND fn_zone_has_tile(panel_zone_id, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'solarReadings.solarPanelId must reference a solar panel in a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_batteries_validate_zone $$
CREATE TRIGGER trg_batteries_validate_zone
BEFORE INSERT ON batteries
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'batteries.zoneId must reference a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_batteries_validate_zone_update $$
CREATE TRIGGER trg_batteries_validate_zone_update
BEFORE UPDATE ON batteries
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'batteries.zoneId must reference a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_battery_levels_validate_zone $$
CREATE TRIGGER trg_battery_levels_validate_zone
BEFORE INSERT ON batteryLevels
FOR EACH ROW
BEGIN
  DECLARE battery_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO battery_zone_id
    FROM batteries
   WHERE batteryId = NEW.batteryId;

  IF battery_zone_id IS NOT NULL AND fn_zone_has_tile(battery_zone_id, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'batteryLevels.batteryId must reference a battery in a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_battery_levels_validate_zone_update $$
CREATE TRIGGER trg_battery_levels_validate_zone_update
BEFORE UPDATE ON batteryLevels
FOR EACH ROW
BEGIN
  DECLARE battery_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO battery_zone_id
    FROM batteries
   WHERE batteryId = NEW.batteryId;

  IF battery_zone_id IS NOT NULL AND fn_zone_has_tile(battery_zone_id, 'Power Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'batteryLevels.batteryId must reference a battery in a Power Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_fields_validate_zone $$
CREATE TRIGGER trg_fields_validate_zone
BEFORE INSERT ON fields
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'fields.zoneId must reference a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_fields_validate_zone_update $$
CREATE TRIGGER trg_fields_validate_zone_update
BEFORE UPDATE ON fields
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'fields.zoneId must reference a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_plantings_validate_zone $$
CREATE TRIGGER trg_crop_plantings_validate_zone
BEFORE INSERT ON cropPlantings
FOR EACH ROW
BEGIN
  DECLARE field_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO field_zone_id
    FROM fields
   WHERE fieldId = NEW.fieldId;

  IF field_zone_id IS NOT NULL AND fn_zone_has_tile(field_zone_id, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'cropPlantings.fieldId must reference a field in a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_plantings_validate_zone_update $$
CREATE TRIGGER trg_crop_plantings_validate_zone_update
BEFORE UPDATE ON cropPlantings
FOR EACH ROW
BEGIN
  DECLARE field_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO field_zone_id
    FROM fields
   WHERE fieldId = NEW.fieldId;

  IF field_zone_id IS NOT NULL AND fn_zone_has_tile(field_zone_id, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'cropPlantings.fieldId must reference a field in a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_harvest_records_validate_zone $$
CREATE TRIGGER trg_harvest_records_validate_zone
BEFORE INSERT ON harvestRecords
FOR EACH ROW
BEGIN
  DECLARE field_zone_id INT DEFAULT NULL;

  SELECT f.zoneId
    INTO field_zone_id
    FROM cropPlantings cp
    JOIN fields f ON f.fieldId = cp.fieldId
   WHERE cp.cropPlantingId = NEW.plantingId;

  IF field_zone_id IS NOT NULL AND fn_zone_has_tile(field_zone_id, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'harvestRecords.plantingId must reference a planting in a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_harvest_records_validate_zone_update $$
CREATE TRIGGER trg_harvest_records_validate_zone_update
BEFORE UPDATE ON harvestRecords
FOR EACH ROW
BEGIN
  DECLARE field_zone_id INT DEFAULT NULL;

  SELECT f.zoneId
    INTO field_zone_id
    FROM cropPlantings cp
    JOIN fields f ON f.fieldId = cp.fieldId
   WHERE cp.cropPlantingId = NEW.plantingId;

  IF field_zone_id IS NOT NULL AND fn_zone_has_tile(field_zone_id, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'harvestRecords.plantingId must reference a planting in a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_ai_predictions_validate_zone $$
CREATE TRIGGER trg_crop_ai_predictions_validate_zone
BEFORE INSERT ON cropAiPredictions
FOR EACH ROW
BEGIN
  DECLARE field_zone_id INT DEFAULT NULL;

  SELECT f.zoneId
    INTO field_zone_id
    FROM cropImages ci
    JOIN cropPlantings cp ON cp.cropPlantingId = ci.plantingId
    JOIN fields f ON f.fieldId = cp.fieldId
   WHERE ci.cropImageId = NEW.imageId;

  IF field_zone_id IS NOT NULL AND fn_zone_has_tile(field_zone_id, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'cropAiPredictions.imageId must reference a crop image in a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_crop_ai_predictions_validate_zone_update $$
CREATE TRIGGER trg_crop_ai_predictions_validate_zone_update
BEFORE UPDATE ON cropAiPredictions
FOR EACH ROW
BEGIN
  DECLARE field_zone_id INT DEFAULT NULL;

  SELECT f.zoneId
    INTO field_zone_id
    FROM cropImages ci
    JOIN cropPlantings cp ON cp.cropPlantingId = ci.plantingId
    JOIN fields f ON f.fieldId = cp.fieldId
   WHERE ci.cropImageId = NEW.imageId;

  IF field_zone_id IS NOT NULL AND fn_zone_has_tile(field_zone_id, 'Crop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'cropAiPredictions.imageId must reference a crop image in a Crop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_coops_validate_zone $$
CREATE TRIGGER trg_coops_validate_zone
BEFORE INSERT ON coops
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'coops.zoneId must reference a Chicken Coop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_coops_validate_zone_update $$
CREATE TRIGGER trg_coops_validate_zone_update
BEFORE UPDATE ON coops
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'coops.zoneId must reference a Chicken Coop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_chickens_validate_zone $$
CREATE TRIGGER trg_chickens_validate_zone
BEFORE INSERT ON chickens
FOR EACH ROW
BEGIN
  DECLARE coop_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NOT NULL THEN
    SELECT zoneId
      INTO coop_zone_id
      FROM coops
     WHERE coopId = NEW.coopId;

    IF coop_zone_id IS NOT NULL AND fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'chickens.coopId must reference a coop in a Chicken Coop Tile zone.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_chickens_validate_zone_update $$
CREATE TRIGGER trg_chickens_validate_zone_update
BEFORE UPDATE ON chickens
FOR EACH ROW
BEGIN
  DECLARE coop_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NOT NULL THEN
    SELECT zoneId
      INTO coop_zone_id
      FROM coops
     WHERE coopId = NEW.coopId;

    IF coop_zone_id IS NOT NULL AND fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'chickens.coopId must reference a coop in a Chicken Coop Tile zone.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_chicken_eggs_validate_zone $$
CREATE TRIGGER trg_chicken_eggs_validate_zone
BEFORE INSERT ON chickenEggs
FOR EACH ROW
BEGIN
  DECLARE chicken_zone_id INT DEFAULT NULL;

  SELECT c.zoneId
    INTO chicken_zone_id
    FROM chickens ch
    LEFT JOIN coops c ON c.coopId = ch.coopId
   WHERE ch.rfid = NEW.rfid;

  IF chicken_zone_id IS NOT NULL AND fn_zone_has_tile(chicken_zone_id, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'chickenEggs.rfid must reference a chicken assigned to a Chicken Coop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_chicken_eggs_validate_zone_update $$
CREATE TRIGGER trg_chicken_eggs_validate_zone_update
BEFORE UPDATE ON chickenEggs
FOR EACH ROW
BEGIN
  DECLARE chicken_zone_id INT DEFAULT NULL;

  SELECT c.zoneId
    INTO chicken_zone_id
    FROM chickens ch
    LEFT JOIN coops c ON c.coopId = ch.coopId
   WHERE ch.rfid = NEW.rfid;

  IF chicken_zone_id IS NOT NULL AND fn_zone_has_tile(chicken_zone_id, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'chickenEggs.rfid must reference a chicken assigned to a Chicken Coop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_coop_cleaning_logs_validate_zone $$
CREATE TRIGGER trg_coop_cleaning_logs_validate_zone
BEFORE INSERT ON coopCleaningLogs
FOR EACH ROW
BEGIN
  DECLARE coop_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NOT NULL THEN
    SELECT zoneId
      INTO coop_zone_id
      FROM coops
     WHERE coopId = NEW.coopId;

    IF coop_zone_id IS NOT NULL AND fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'coopCleaningLogs.coopId must reference a Chicken Coop Tile zone.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_coop_cleaning_logs_validate_zone_update $$
CREATE TRIGGER trg_coop_cleaning_logs_validate_zone_update
BEFORE UPDATE ON coopCleaningLogs
FOR EACH ROW
BEGIN
  DECLARE coop_zone_id INT DEFAULT NULL;

  IF NEW.coopId IS NOT NULL THEN
    SELECT zoneId
      INTO coop_zone_id
      FROM coops
     WHERE coopId = NEW.coopId;

    IF coop_zone_id IS NOT NULL AND fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'coopCleaningLogs.coopId must reference a Chicken Coop Tile zone.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_feed_records_validate_zone $$
CREATE TRIGGER trg_feed_records_validate_zone
BEFORE INSERT ON feedRecords
FOR EACH ROW
BEGIN
  DECLARE coop_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO coop_zone_id
    FROM coops
   WHERE coopId = NEW.coopId;

  IF coop_zone_id IS NOT NULL AND fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'feedRecords.coopId must reference a Chicken Coop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_feed_records_validate_zone_update $$
CREATE TRIGGER trg_feed_records_validate_zone_update
BEFORE UPDATE ON feedRecords
FOR EACH ROW
BEGIN
  DECLARE coop_zone_id INT DEFAULT NULL;

  SELECT zoneId
    INTO coop_zone_id
    FROM coops
   WHERE coopId = NEW.coopId;

  IF coop_zone_id IS NOT NULL AND fn_zone_has_tile(coop_zone_id, 'Chicken Coop Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'feedRecords.coopId must reference a Chicken Coop Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_animal_health_logs_validate_zone $$
CREATE TRIGGER trg_animal_health_logs_validate_zone
BEFORE INSERT ON animalHealthLogs
FOR EACH ROW
BEGIN
  DECLARE chicken_zone_id INT DEFAULT NULL;

  IF NEW.rfid IS NOT NULL THEN
    SELECT c.zoneId
      INTO chicken_zone_id
      FROM chickens ch
      LEFT JOIN coops c ON c.coopId = ch.coopId
     WHERE ch.rfid = NEW.rfid;

    IF chicken_zone_id IS NOT NULL AND fn_zone_has_tile(chicken_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'animalHealthLogs.rfid must reference a chicken assigned to a Chicken Coop Tile zone.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_animal_health_logs_validate_zone_update $$
CREATE TRIGGER trg_animal_health_logs_validate_zone_update
BEFORE UPDATE ON animalHealthLogs
FOR EACH ROW
BEGIN
  DECLARE chicken_zone_id INT DEFAULT NULL;

  IF NEW.rfid IS NOT NULL THEN
    SELECT c.zoneId
      INTO chicken_zone_id
      FROM chickens ch
      LEFT JOIN coops c ON c.coopId = ch.coopId
     WHERE ch.rfid = NEW.rfid;

    IF chicken_zone_id IS NOT NULL AND fn_zone_has_tile(chicken_zone_id, 'Chicken Coop Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'animalHealthLogs.rfid must reference a chicken assigned to a Chicken Coop Tile zone.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_water_sources_validate_zone $$
CREATE TRIGGER trg_water_sources_validate_zone
BEFORE INSERT ON waterSources
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Water Distribution Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'waterSources.zoneId must reference a Water Distribution Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_water_sources_validate_zone_update $$
CREATE TRIGGER trg_water_sources_validate_zone_update
BEFORE UPDATE ON waterSources
FOR EACH ROW
BEGIN
  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Water Distribution Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'waterSources.zoneId must reference a Water Distribution Tile zone.';
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_water_distribution_nodes_validate_zone $$
CREATE TRIGGER trg_water_distribution_nodes_validate_zone
BEFORE INSERT ON waterDistributionNodes
FOR EACH ROW
BEGIN
  DECLARE source_zone_id INT DEFAULT NULL;

  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Water Distribution Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'waterDistributionNodes.zoneId must reference a Water Distribution Tile zone.';
  END IF;

  IF NEW.sourceId IS NOT NULL THEN
    SELECT zoneId
      INTO source_zone_id
      FROM waterSources
     WHERE waterSourceId = NEW.sourceId;

    IF source_zone_id IS NOT NULL AND fn_zone_has_tile(source_zone_id, 'Water Distribution Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'waterDistributionNodes.sourceId must reference a water source in a Water Distribution Tile zone.';
    END IF;

    IF NEW.zoneId IS NOT NULL AND fn_same_farm_for_zones(source_zone_id, NEW.zoneId) = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'waterDistributionNodes.zoneId and sourceId must belong to the same farm.';
    END IF;
  END IF;
END $$

DROP TRIGGER IF EXISTS trg_water_distribution_nodes_validate_zone_update $$
CREATE TRIGGER trg_water_distribution_nodes_validate_zone_update
BEFORE UPDATE ON waterDistributionNodes
FOR EACH ROW
BEGIN
  DECLARE source_zone_id INT DEFAULT NULL;

  IF NEW.zoneId IS NOT NULL AND fn_zone_has_tile(NEW.zoneId, 'Water Distribution Tile') = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'waterDistributionNodes.zoneId must reference a Water Distribution Tile zone.';
  END IF;

  IF NEW.sourceId IS NOT NULL THEN
    SELECT zoneId
      INTO source_zone_id
      FROM waterSources
     WHERE waterSourceId = NEW.sourceId;

    IF source_zone_id IS NOT NULL AND fn_zone_has_tile(source_zone_id, 'Water Distribution Tile') = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'waterDistributionNodes.sourceId must reference a water source in a Water Distribution Tile zone.';
    END IF;

    IF NEW.zoneId IS NOT NULL AND fn_same_farm_for_zones(source_zone_id, NEW.zoneId) = 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'waterDistributionNodes.zoneId and sourceId must belong to the same farm.';
    END IF;
  END IF;
END $$

DELIMITER ;


/* ================================================================
   SEED DATA
   ================================================================ */

/* Roles */
INSERT INTO roles (roleName, description) VALUES
  ('Visitor', 'Default website role with public-facing read access.'),
  ('PSU Student', 'PSU student contributor with supervised access to project data.'),
  ('BC Student', 'BC student contributor with supervised access to project data.'),
  ('Farm Staff', 'Operational staff responsible for day-to-day farm activities.'),
  ('Farmer', 'Farmer role with access to farming operations and records.'),
  ('Farm Admin', 'Administrative role scoped to a specific farm.'),
  ('Admin', 'Full platform administration across farms, users, and content.'),
  ('Moderator', 'Moderates website content and operational updates.');

/* Tiles */
INSERT INTO tiles (tileName, description) VALUES
  ('Power Tile', 'Power generation and storage infrastructure.'),
  ('Crop Tile', 'Crop growing fields and supporting crop records.'),
  ('Chicken Coop Tile', 'Chicken coops and poultry management areas.'),
  ('Water Distribution Tile', 'Water sources and the downstream distribution network.'),
  ('Internet Hub Tile', 'Central communications and connectivity infrastructure.');

/* Farms */
INSERT INTO farms (farmName, description)
VALUES ('Bela-Bela Primary School', 'Test dataset for the Bela-Bela Primary School smart farm deployment.');

/* Default admin user — generate a hashed password value in the application before deploying.
   On login, verify the entered password against the stored hash with Argon2id/bcrypt verify.
*/
INSERT INTO users (firstName, lastName, username, email, password, roleId, farmId, institution)
VALUES (
  'Platform', 'Admin',
  'BCPSU_admin',
  'admin@bbps.smartfarm.local',
  '$2a$12$L.6fwCWlCAA6OU5wRZpfT.EhhQpdw.h.oFHHNBFg6oLkieAVDX3cS',
  (SELECT roleId FROM roles WHERE roleName = 'Admin'),
  (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School'),
  'Bela-Bela Primary School'
);

/* Zone-scoped seed dataset: each tile-specific record uses only zones from the matching tile. */
INSERT INTO farmZones (farmId, zoneName, tileId, description, areaSqMeter) VALUES
  ((SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School'), 'Solar Yard',             (SELECT tileId FROM tiles WHERE tileName = 'Power Tile'),              'Power tile zone for solar generation and battery storage only.', 850.00),
  ((SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School'), 'Vegetable Garden Block', (SELECT tileId FROM tiles WHERE tileName = 'Crop Tile'),               'Crop tile zone for fields, crops, and planting activity.', 1200.00),
  ((SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School'), 'Layer Coop East',        (SELECT tileId FROM tiles WHERE tileName = 'Chicken Coop Tile'),       'Chicken tile zone for poultry housing and monitoring.', 320.00),
  ((SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School'), 'Borehole Intake',        (SELECT tileId FROM tiles WHERE tileName = 'Water Distribution Tile'), 'Water tile zone for raw water intake and storage.', 180.00),
  ((SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School'), 'Distribution Line East', (SELECT tileId FROM tiles WHERE tileName = 'Water Distribution Tile'), 'Water tile zone for downstream pumps, valves, and trough feeds.', 260.00),
  ((SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School'), 'Connectivity Hub',       (SELECT tileId FROM tiles WHERE tileName = 'Internet Hub Tile'),       'Internet hub zone for gateway and backhaul equipment.', 90.00);

INSERT INTO devices (zoneId, deviceName, deviceType, location, protocol, status, macAddress, firmwareVersion, lastSeen, notes) VALUES
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Solar Yard' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Solar Inverter Controller', 'power_controller', 'Solar Yard inverter rack', 'WiFi', 'online', 'AA:BB:CC:10:00:01', 'v1.4.2', '2026-04-25 07:45:00', 'Power tile device used only for the solar yard zone.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Solar Yard' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Battery Bank Monitor', 'battery_monitor', 'Battery container north wall', 'LoRa', 'online', 'AA:BB:CC:10:00:02', 'v1.3.8', '2026-04-25 07:42:00', 'Power tile device used only for solar storage assets.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Vegetable Garden Block' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Crop Climate Node', 'temp_humidity', 'Vegetable block weather pole', 'LoRa', 'online', 'AA:BB:CC:20:00:01', 'v2.0.1', '2026-04-25 07:40:00', 'Crop tile device assigned only to the vegetable garden block.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Vegetable Garden Block' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Soil Moisture Station', 'moisture', 'Vegetable block bed A', 'LoRa', 'online', 'AA:BB:CC:20:00:02', 'v2.0.1', '2026-04-25 07:41:00', 'Crop tile device assigned only to crop-zone field activity.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Layer Coop East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Coop RFID Reader', 'rfid_reader', 'Layer Coop East main entry', 'WiFi', 'online', 'AA:BB:CC:30:00:01', 'v3.1.0', '2026-04-25 07:35:00', 'Chicken tile device dedicated to coop access events.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Layer Coop East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Coop Door Controller', 'door_controller', 'Layer Coop East service panel', 'WiFi', 'maintenance', 'AA:BB:CC:30:00:02', 'v3.0.4', '2026-04-24 18:10:00', 'Chicken tile device dedicated to door automation in the coop zone.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Borehole Intake' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Borehole Level Sensor', 'level_sensor', 'Borehole Intake tank', 'LoRa', 'online', 'AA:BB:CC:40:00:01', 'v1.8.5', '2026-04-25 07:30:00', 'Water tile device dedicated to the borehole intake zone.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Distribution Line East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Valve Controller East', 'valve_controller', 'Distribution Line East manifold', 'LoRa', 'online', 'AA:BB:CC:40:00:02', 'v1.9.0', '2026-04-25 07:32:00', 'Water tile device dedicated to downstream valve control.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Distribution Line East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Water Flow Node East', 'flow_sensor', 'Distribution Line East pump station', 'LoRa', 'online', 'AA:BB:CC:40:00:03', 'v1.9.0', '2026-04-25 07:33:00', 'Water tile device dedicated to the east distribution line zone.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Connectivity Hub' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Campus Meshtastic Gateway', 'gateway', 'Connectivity Hub mast', 'Meshtastic', 'online', 'AA:BB:CC:50:00:01', 'v4.2.0', '2026-04-25 07:20:00', 'Internet hub device dedicated to connectivity infrastructure only.');

INSERT INTO solarPanel (zoneId, panelName, capacityKW, installedDate, notes) VALUES
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Solar Yard' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Solar Array A', 8.500, '2025-11-15', 'Primary solar array for the school pilot site.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Solar Yard' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Solar Array B', 8.500, '2025-11-16', 'Secondary solar array paired with the main inverter.');

INSERT INTO batteries (zoneId, batteryName, maxKW, installedDate, notes) VALUES
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Solar Yard' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Battery Bank A', 12.000, '2025-11-20', 'Primary battery bank for daytime energy storage.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Solar Yard' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Battery Bank B', 12.000, '2025-11-20', 'Secondary battery bank for overnight reserve capacity.');

INSERT INTO fields (zoneId, fieldName, areaM2, soilType, notes) VALUES
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Vegetable Garden Block' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Spinach Demonstration Field', 450.00, 'Loam', 'Crop tile field reserved for leafy green production.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Vegetable Garden Block' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'Tomato Tunnel Plot', 300.00, 'Sandy Loam', 'Crop tile field reserved for protected tomato cultivation.');

INSERT INTO crops (commonName, scientificName, variety, growthDurationDays, notes) VALUES
  ('Spinach', 'Spinacia oleracea', 'Fordhook Giant', 45, 'Fast-growing leafy crop used for classroom demonstration beds.'),
  ('Tomato', 'Solanum lycopersicum', 'Roma VF', 90, 'Field and tunnel crop suited to the Bela-Bela pilot conditions.'),
  ('Cabbage', 'Brassica oleracea var. capitata', 'Green Coronet', 80, 'Cool-season crop used for rotational planting trials.');

INSERT INTO cropPlantings (fieldId, cropId, cropStatus, plantedDate, expectedHarvestDate, actualHarvestDate, notes) VALUES
  (1, 1, 'harvested', '2026-01-10', '2026-02-24', '2026-02-26', 'Completed summer teaching cycle for the spinach demonstration bed.'),
  (1, 1, 'growing', '2026-04-05', '2026-05-20', NULL, 'Second spinach cycle currently in active growth.'),
  (2, 3, 'failed', '2025-11-20', '2026-02-08', NULL, 'Early cabbage trial failed due to heat stress and uneven irrigation.'),
  (2, 2, 'growing', '2026-02-15', '2026-05-16', NULL, 'Main Roma tomato cycle for the current term.'),
  (2, 2, 'ready_to_harvest', '2026-01-12', '2026-04-12', NULL, 'Tomato plot nearing the harvest window.');

INSERT INTO coops (zoneId, coopName, capacity, notes, doorOpen, doorClose, reminderPeriod) VALUES
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Layer Coop East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'East Layer Coop 1', 120, 'Primary laying coop for the chicken tile zone.', '06:00:00', '18:00:00', 7),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Layer Coop East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'East Brooder Coop', 40, 'Smaller coop for younger birds and temporary isolation.', '06:30:00', '17:30:00', 3);

INSERT INTO chickens (rfid, coopId, chickenName, gender, dateOfBirth, species, weightKg, notes) VALUES
  ('RFID-BBPS-0001', (SELECT coopId FROM coops WHERE coopName = 'East Layer Coop 1'), 'Nala', 'female', '2025-08-14', 'Hy-Line Brown', 1.850, 'Healthy layer assigned to the main laying coop.'),
  ('RFID-BBPS-0002', (SELECT coopId FROM coops WHERE coopName = 'East Layer Coop 1'), 'Lebo', 'female', '2025-08-20', 'Hy-Line Brown', 1.790, 'Healthy layer used for RFID tracking demonstrations.'),
  ('RFID-BBPS-0003', (SELECT coopId FROM coops WHERE coopName = 'East Brooder Coop'), 'Sunny', 'female', '2025-11-02', 'Rhode Island Red', 1.220, 'Growing pullet kept in the brooder coop.'),
  ('RFID-BBPS-0004', (SELECT coopId FROM coops WHERE coopName = 'East Brooder Coop'), 'Rocky', 'male', '2025-11-05', 'Rhode Island Red', 1.340, 'Test rooster record for coop monitoring scenarios.');

INSERT INTO waterSources (zoneId, waterSourceType, waterSourceName, capacityLiters, notes) VALUES
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Borehole Intake' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'borehole', 'Borehole Alpha', 25000.00, 'Primary raw water source located at the borehole intake zone.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Borehole Intake' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), 'reservoir', 'Header Tank North', 12000.00, 'Storage reservoir feeding the downstream east distribution line.');

INSERT INTO waterDistributionNodes (zoneId, sourceId, nodeName, nodeType, notes) VALUES
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Distribution Line East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), (SELECT waterSourceId FROM waterSources WHERE waterSourceName = 'Borehole Alpha'), 'Main Pump Station', 'pump', 'Pump node supplied from Borehole Alpha into the east distribution line.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Distribution Line East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), (SELECT waterSourceId FROM waterSources WHERE waterSourceName = 'Borehole Alpha'), 'Valve Manifold East', 'valve', 'Valve cluster serving crop and poultry water routes.'),
  ((SELECT farmZoneId FROM farmZones WHERE zoneName = 'Distribution Line East' AND farmId = (SELECT farmId FROM farms WHERE farmName = 'Bela-Bela Primary School')), (SELECT waterSourceId FROM waterSources WHERE waterSourceName = 'Header Tank North'), 'Poultry Trough Feed', 'trough', 'Delivery node feeding the poultry watering line from the header tank.');

SET FOREIGN_KEY_CHECKS = 1;
