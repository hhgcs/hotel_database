USE HotelDatabase;
GO

SET NOCOUNT ON;
GO

INSERT dbo.ROLES(rol_name)
VALUES
    (N'Admin'),
    (N'Receptionist'),
    (N'Manager'),
    (N'Housekeeping');

;WITH numbers AS
(
    SELECT TOP (996) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 4 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.ROLES(rol_name)
SELECT CONCAT(N'Role ', n)
FROM numbers;

INSERT dbo.RESERVATION_STATES(reservation_state_name)
VALUES
    (N'Pending'),
    (N'Confirmed'),
    (N'InProgress'),
    (N'Finished'),
    (N'Cancelled');

;WITH numbers AS
(
    SELECT TOP (995) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 5 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.RESERVATION_STATES(reservation_state_name)
SELECT CONCAT(N'Reservation State ', n)
FROM numbers;

INSERT dbo.ROOM_STATES(state_name)
VALUES
    (N'Available'),
    (N'Occupied'),
    (N'Cleaning'),
    (N'Maintenance');

;WITH numbers AS
(
    SELECT TOP (996) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 4 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.ROOM_STATES(state_name)
SELECT CONCAT(N'Room State ', n)
FROM numbers;

INSERT dbo.STAY_STATES(stay_state_name)
VALUES
    (N'Active'),
    (N'Finished'),
    (N'Cancelled');

;WITH numbers AS
(
    SELECT TOP (997) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 3 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.STAY_STATES(stay_state_name)
SELECT CONCAT(N'Stay State ', n)
FROM numbers;

INSERT dbo.RESERVATION_SERVICE_STATES(reservation_service_state_name)
VALUES
    (N'Reserved'),
    (N'Consumed'),
    (N'Cancelled');

;WITH numbers AS
(
    SELECT TOP (997) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 3 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.RESERVATION_SERVICE_STATES(reservation_service_state_name)
SELECT CONCAT(N'Reservation Service State ', n)
FROM numbers;

INSERT dbo.CHARGE_TYPES(name)
VALUES
    (N'Room'),
    (N'Service'),
    (N'Tax'),
    (N'Penalty'),
    (N'Adjustment');

;WITH numbers AS
(
    SELECT TOP (995) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 5 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.CHARGE_TYPES(name)
SELECT CONCAT(N'Charge Type ', n)
FROM numbers;

INSERT dbo.PAYMENT_METHODS(payment_method_name)
VALUES
    (N'Cash'),
    (N'Credit Card'),
    (N'Debit Card'),
    (N'Bank Transfer');

;WITH numbers AS
(
    SELECT TOP (996) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 4 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.PAYMENT_METHODS(payment_method_name)
SELECT CONCAT(N'Payment Method ', n)
FROM numbers;

INSERT dbo.PAYMENT_STATES(payment_state_name)
VALUES
    (N'Paid'),
    (N'Pending'),
    (N'Failed'),
    (N'Refunded');

;WITH numbers AS
(
    SELECT TOP (996) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 4 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.PAYMENT_STATES(payment_state_name)
SELECT CONCAT(N'Payment State ', n)
FROM numbers;

INSERT dbo.ROOM_TYPES(name, capacity, price)
VALUES
    (N'Standard Single', 1, 900.00),
    (N'Standard Double', 2, 1200.00),
    (N'Family Room', 4, 1800.00),
    (N'Junior Suite', 3, 2500.00),
    (N'Executive Suite', 4, 3800.00);

;WITH numbers AS
(
    SELECT TOP (995) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 5 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.ROOM_TYPES(name, capacity, price)
SELECT
    CONCAT(N'Room Type ', n),
    (n % 4) + 1,
    CONVERT(DECIMAL(10,2), 800 + n)
FROM numbers;

INSERT dbo.SERVICES(name, price, capacity, description, availability, reservation_needed)
VALUES
    (N'Breakfast Buffet', 220.00, 300, N'Breakfast service in the main restaurant.', 1, 1),
    (N'Spa Session', 900.00, 40, N'Spa access and massage reservation.', 1, 1),
    (N'Airport Shuttle', 550.00, 80, N'One-way hotel airport transportation.', 1, 1),
    (N'Conference Room', 3500.00, 20, N'Conference room rental by event block.', 1, 1),
    (N'Laundry Service', 180.00, 500, N'Per-bag laundry service.', 1, 0),
    (N'Room Service Dinner', 420.00, 250, N'Dinner delivered to the guest room.', 1, 0),
    (N'Gym Class', 160.00, 30, N'Instructor-led fitness class.', 1, 1),
    (N'City Tour', 750.00, 60, N'Guided city tour.', 1, 1),
    (N'Parking', 140.00, 200, N'Guest vehicle parking per night.', 1, 0),
    (N'Late Checkout', 650.00, 100, N'Approved late checkout service.', 1, 1);

;WITH numbers AS
(
    SELECT TOP (990) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 10 AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.SERVICES(name, price, capacity, description, availability, reservation_needed)
SELECT
    CONCAT(N'Service ', n),
    CONVERT(DECIMAL(10,2), 100 + n),
    100,
    CONCAT(N'Generated service ', n, N'.'),
    1,
    CASE WHEN n % 2 = 0 THEN 1 ELSE 0 END
FROM numbers;

DECLARE @AdminRoleId INT = (SELECT role_id FROM dbo.ROLES WHERE rol_name = N'Admin');
DECLARE @ReceptionRoleId INT = (SELECT role_id FROM dbo.ROLES WHERE rol_name = N'Receptionist');
DECLARE @ManagerRoleId INT = (SELECT role_id FROM dbo.ROLES WHERE rol_name = N'Manager');
DECLARE @HousekeepingRoleId INT = (SELECT role_id FROM dbo.ROLES WHERE rol_name = N'Housekeeping');

;WITH numbers AS
(
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.USERS(first_name, last_name, email, salt, role_id, password_hash, username, active)
SELECT
    CONCAT(N'User', n),
    N'Hotel',
    CONCAT(N'user', n, N'@hotel.local'),
    s.salt,
    CASE
        WHEN n = 1 THEN @AdminRoleId
        WHEN n BETWEEN 2 AND 10 THEN @ReceptionRoleId
        WHEN n BETWEEN 11 AND 14 THEN @ManagerRoleId
        ELSE @HousekeepingRoleId
    END,
    dbo.fn_PasswordHash(CONCAT(N'Password', n, N'!'), s.salt),
    CASE WHEN n = 1 THEN N'admin' ELSE CONCAT(N'reception', n - 1) END,
    1
FROM numbers
CROSS APPLY (VALUES (CRYPT_GEN_RANDOM(16))) AS s(salt);

DECLARE @AvailableRoomStateId INT = (SELECT state_id FROM dbo.ROOM_STATES WHERE state_name = N'Available');

;WITH numbers AS
(
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
),
room_types AS
(
    SELECT room_type_id, ROW_NUMBER() OVER (ORDER BY room_type_id) AS rn
    FROM dbo.ROOM_TYPES
)
INSERT dbo.ROOMS(room_type_id, room_floor, room_number, state_id)
SELECT
    rt.room_type_id,
    ((n.n - 1) / 20) + 1,
    CONCAT(((n.n - 1) / 20) + 1, RIGHT(CONCAT(N'00', ((n.n - 1) % 20) + 1), 2)),
    @AvailableRoomStateId
FROM numbers AS n
INNER JOIN room_types AS rt
    ON rt.rn = ((n.n - 1) % 5) + 1;

OPEN SYMMETRIC KEY SymmetricKey_HotelClientData
    DECRYPTION BY CERTIFICATE Certificate_HotelClientData;

;WITH numbers AS
(
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT dbo.CLIENT(first_name, last_name, email_encrypted, email_hash, phone_number_encrypted)
SELECT
    CONCAT(N'Client', n),
    CONCAT(N'LastName', n),
    EncryptByKey(Key_GUID(N'SymmetricKey_HotelClientData'), CONCAT(N'client', n, N'@example.com')),
    dbo.fn_EmailHash(CONCAT(N'client', n, N'@example.com')),
    EncryptByKey(Key_GUID(N'SymmetricKey_HotelClientData'), CONCAT(N'+52-555-', RIGHT(CONCAT(N'0000', n), 4)))
FROM numbers;

CLOSE SYMMETRIC KEY SymmetricKey_HotelClientData;

DECLARE @FinishedReservationStateId INT =
    (SELECT reservation_state_id FROM dbo.RESERVATION_STATES WHERE reservation_state_name = N'Finished');
DECLARE @FinishedStayStateId INT =
    (SELECT stay_state_id FROM dbo.STAY_STATES WHERE stay_state_name = N'Finished');
DECLARE @ConsumedServiceStateId INT =
    (SELECT reservation_service_state_id FROM dbo.RESERVATION_SERVICE_STATES WHERE reservation_service_state_name = N'Consumed');
DECLARE @RoomChargeTypeId INT =
    (SELECT charge_type_id FROM dbo.CHARGE_TYPES WHERE name = N'Room');
DECLARE @ServiceChargeTypeId INT =
    (SELECT charge_type_id FROM dbo.CHARGE_TYPES WHERE name = N'Service');
DECLARE @PaidPaymentStateId INT =
    (SELECT payment_state_id FROM dbo.PAYMENT_STATES WHERE payment_state_name = N'Paid');
DECLARE @SeedUserId INT =
    (SELECT user_id FROM dbo.USERS WHERE username = N'reception1');
DECLARE @TaxRate DECIMAL(5,4) = 0.1600;

;WITH clients AS
(
    SELECT TOP (1000)
        client_id,
        ROW_NUMBER() OVER (ORDER BY client_id) AS rn
    FROM dbo.CLIENT
    ORDER BY client_id
)
INSERT dbo.RESERVATIONS(client_id, check_in_date, check_out_date, reservation_state_id, creation_date)
SELECT
    client_id,
    DATEADD(DAY, ((rn - 1) / 100) * 3, CONVERT(DATE, '2025-01-01')),
    DATEADD(DAY, ((rn - 1) / 100) * 3 + 2, CONVERT(DATE, '2025-01-01')),
    @FinishedReservationStateId,
    DATEADD(DAY, -30, DATEADD(DAY, ((rn - 1) / 100) * 3, CONVERT(DATE, '2025-01-01')))
FROM clients;

;WITH reservations AS
(
    SELECT reservation_id, ROW_NUMBER() OVER (ORDER BY reservation_id) AS rn
    FROM dbo.RESERVATIONS
),
rooms AS
(
    SELECT room_id, ROW_NUMBER() OVER (ORDER BY room_id) AS rn
    FROM dbo.ROOMS
)
INSERT dbo.RESERVATION_ROOMS(reservation_id, room_id)
SELECT
    r.reservation_id,
    rm.room_id
FROM reservations AS r
INNER JOIN rooms AS rm
    ON rm.rn = ((r.rn - 1) % 1000) + 1;

;WITH reservation_data AS
(
    SELECT reservation_id, check_in_date, check_out_date
    FROM dbo.RESERVATIONS
)
INSERT dbo.STAYS(reservation_id, check_in_date, check_out_date, user_check_in_id, user_check_out_id, stay_state_id)
SELECT
    reservation_id,
    DATEADD(HOUR, 15, CONVERT(DATETIME2(0), check_in_date)),
    DATEADD(HOUR, 11, CONVERT(DATETIME2(0), check_out_date)),
    @SeedUserId,
    @SeedUserId,
    @FinishedStayStateId
FROM reservation_data;

;WITH reservations AS
(
    SELECT reservation_id, check_in_date, ROW_NUMBER() OVER (ORDER BY reservation_id) AS rn
    FROM dbo.RESERVATIONS
),
services AS
(
    SELECT service_id, price, ROW_NUMBER() OVER (ORDER BY service_id) AS rn
    FROM dbo.SERVICES
)
INSERT dbo.RESERVATION_SERVICES(reservation_id, service_id, service_date, quantity, unitary_price, reservation_service_state_id)
SELECT
    r.reservation_id,
    s.service_id,
    DATEADD(HOUR, 10, DATEADD(DAY, 1, CONVERT(DATETIME2(0), r.check_in_date))),
    1,
    s.price,
    @ConsumedServiceStateId
FROM reservations AS r
INNER JOIN services AS s
    ON s.rn = ((r.rn - 1) % 10) + 1;

INSERT dbo.CHARGES
(
    reservation_id,
    charge_type_id,
    reservation_room_id,
    description,
    quantity,
    unitary_price,
    subtotal,
    taxes,
    total,
    charge_date
)
SELECT
    r.reservation_id,
    @RoomChargeTypeId,
    rr.reservation_room_id,
    CONCAT(N'Room charge - room ', rm.room_number),
    DATEDIFF(DAY, r.check_in_date, r.check_out_date),
    rt.price,
    DATEDIFF(DAY, r.check_in_date, r.check_out_date) * rt.price,
    ROUND(DATEDIFF(DAY, r.check_in_date, r.check_out_date) * rt.price * @TaxRate, 2),
    (DATEDIFF(DAY, r.check_in_date, r.check_out_date) * rt.price)
        + ROUND(DATEDIFF(DAY, r.check_in_date, r.check_out_date) * rt.price * @TaxRate, 2),
    DATEADD(HOUR, 10, CONVERT(DATETIME2(0), r.check_out_date))
FROM dbo.RESERVATION_ROOMS AS rr
INNER JOIN dbo.RESERVATIONS AS r
    ON r.reservation_id = rr.reservation_id
INNER JOIN dbo.ROOMS AS rm
    ON rm.room_id = rr.room_id
INNER JOIN dbo.ROOM_TYPES AS rt
    ON rt.room_type_id = rm.room_type_id;

INSERT dbo.CHARGES
(
    reservation_id,
    charge_type_id,
    reservation_service_id,
    description,
    quantity,
    unitary_price,
    subtotal,
    taxes,
    total,
    charge_date
)
SELECT
    rs.reservation_id,
    @ServiceChargeTypeId,
    rs.reservation_service_id,
    CONCAT(N'Service charge - ', s.name),
    rs.quantity,
    rs.unitary_price,
    rs.quantity * rs.unitary_price,
    ROUND(rs.quantity * rs.unitary_price * @TaxRate, 2),
    (rs.quantity * rs.unitary_price) + ROUND(rs.quantity * rs.unitary_price * @TaxRate, 2),
    rs.service_date
FROM dbo.RESERVATION_SERVICES AS rs
INNER JOIN dbo.SERVICES AS s
    ON s.service_id = rs.service_id;

;WITH reservations AS
(
    SELECT reservation_id, ROW_NUMBER() OVER (ORDER BY reservation_id) AS rn
    FROM dbo.RESERVATIONS
),
payment_methods AS
(
    SELECT payment_method_id, ROW_NUMBER() OVER (ORDER BY payment_method_id) AS rn
    FROM dbo.PAYMENT_METHODS
)
INSERT dbo.PAYMENTS(reservation_id, amount, payment_date, payment_method_id, payment_state_id)
SELECT
    r.reservation_id,
    totals.total_amount,
    DATEADD(HOUR, 12, CONVERT(DATETIME2(0), res.check_out_date)),
    pm.payment_method_id,
    @PaidPaymentStateId
FROM reservations AS r
INNER JOIN dbo.RESERVATIONS AS res
    ON res.reservation_id = r.reservation_id
INNER JOIN payment_methods AS pm
    ON pm.rn = ((r.rn - 1) % 4) + 1
CROSS APPLY
(
    SELECT SUM(total) AS total_amount
    FROM dbo.CHARGES AS ch
    WHERE ch.reservation_id = r.reservation_id
) AS totals;

PRINT 'Seed data loaded.';

SELECT 'CHARGE_TYPES' AS table_name, COUNT(*) AS row_count FROM dbo.CHARGE_TYPES
UNION ALL SELECT 'CHARGES', COUNT(*) FROM dbo.CHARGES
UNION ALL SELECT 'CLIENT', COUNT(*) FROM dbo.CLIENT
UNION ALL SELECT 'PAYMENT_METHODS', COUNT(*) FROM dbo.PAYMENT_METHODS
UNION ALL SELECT 'PAYMENT_STATES', COUNT(*) FROM dbo.PAYMENT_STATES
UNION ALL SELECT 'PAYMENTS', COUNT(*) FROM dbo.PAYMENTS
UNION ALL SELECT 'RESERVATION_ROOMS', COUNT(*) FROM dbo.RESERVATION_ROOMS
UNION ALL SELECT 'RESERVATION_SERVICE_STATES', COUNT(*) FROM dbo.RESERVATION_SERVICE_STATES
UNION ALL SELECT 'RESERVATION_SERVICES', COUNT(*) FROM dbo.RESERVATION_SERVICES
UNION ALL SELECT 'RESERVATION_STATES', COUNT(*) FROM dbo.RESERVATION_STATES
UNION ALL SELECT 'RESERVATIONS', COUNT(*) FROM dbo.RESERVATIONS
UNION ALL SELECT 'ROLES', COUNT(*) FROM dbo.ROLES
UNION ALL SELECT 'ROOM_STATES', COUNT(*) FROM dbo.ROOM_STATES
UNION ALL SELECT 'ROOM_TYPES', COUNT(*) FROM dbo.ROOM_TYPES
UNION ALL SELECT 'ROOMS', COUNT(*) FROM dbo.ROOMS
UNION ALL SELECT 'SERVICES', COUNT(*) FROM dbo.SERVICES
UNION ALL SELECT 'STAY_STATES', COUNT(*) FROM dbo.STAY_STATES
UNION ALL SELECT 'STAYS', COUNT(*) FROM dbo.STAYS
UNION ALL SELECT 'USERS', COUNT(*) FROM dbo.USERS;
GO
