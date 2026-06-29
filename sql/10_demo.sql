USE HotelDatabase;
GO

SET NOCOUNT ON;
GO

DECLARE @Today DATE = CONVERT(DATE, SYSDATETIME());
DECLARE @ClientId INT;
DECLARE @ReservationId INT;
DECLARE @ReservationServiceId INT;
DECLARE @UserId INT = (SELECT user_id FROM dbo.USERS WHERE username = N'reception1');
DECLARE @RoomTypeId INT = (SELECT room_type_id FROM dbo.ROOM_TYPES WHERE name = N'Standard Single');
DECLARE @ServiceId INT = (SELECT service_id FROM dbo.SERVICES WHERE name = N'Breakfast Buffet');
DECLARE @PaymentMethodId INT = (SELECT payment_method_id FROM dbo.PAYMENT_METHODS WHERE payment_method_name = N'Cash');
DECLARE @DemoEmail NVARCHAR(320) = N'demo.client@example.com';
DECLARE @DemoCheckOutDate DATE = DATEADD(DAY, 2, @Today);
DECLARE @DemoServiceDate DATETIME2(0) = DATEADD(HOUR, 9, DATEADD(DAY, 1, CONVERT(DATETIME2(0), @Today)));

PRINT '1. Show encrypted client data before creating the demo client.';
SELECT TOP (5)
    client_id,
    first_name,
    last_name,
    email_encrypted,
    CONVERT(VARCHAR(64), email_hash, 2) AS email_hash_hex,
    phone_number_encrypted
FROM dbo.CLIENT
ORDER BY client_id;

SELECT @ClientId = client_id
FROM dbo.CLIENT
WHERE email_hash = dbo.fn_EmailHash(@DemoEmail);

IF @ClientId IS NULL
BEGIN
    EXEC dbo.sp_CreateClient
        @FirstName = N'Demo',
        @LastName = N'Client',
        @Email = @DemoEmail,
        @PhoneNumber = N'+52-555-0101',
        @ClientId = @ClientId OUTPUT;
END;

PRINT '2. Create a reservation and assign an available room.';
EXEC dbo.sp_CreateReservation
    @ClientId = @ClientId,
    @CheckInDate = @Today,
    @CheckOutDate = @DemoCheckOutDate,
    @RoomTypeId = @RoomTypeId,
    @ReservationId = @ReservationId OUTPUT;

SELECT *
FROM dbo.vw_ActiveReservations
WHERE reservation_id = @ReservationId;

SELECT
    rr.reservation_room_id,
    rr.reservation_id,
    rm.room_number,
    rst.state_name
FROM dbo.RESERVATION_ROOMS AS rr
INNER JOIN dbo.ROOMS AS rm
    ON rm.room_id = rr.room_id
INNER JOIN dbo.ROOM_STATES AS rst
    ON rst.state_id = rm.state_id
WHERE rr.reservation_id = @ReservationId;

PRINT '3. Execute check-in. The room status changes to Occupied.';
EXEC dbo.sp_CheckInClient
    @ReservationId = @ReservationId,
    @UserCheckInId = @UserId;

SELECT
    rr.reservation_id,
    rm.room_number,
    rst.state_name AS room_state,
    ss.stay_state_name,
    st.check_in_date
FROM dbo.RESERVATION_ROOMS AS rr
INNER JOIN dbo.ROOMS AS rm
    ON rm.room_id = rr.room_id
INNER JOIN dbo.ROOM_STATES AS rst
    ON rst.state_id = rm.state_id
INNER JOIN dbo.STAYS AS st
    ON st.reservation_id = rr.reservation_id
INNER JOIN dbo.STAY_STATES AS ss
    ON ss.stay_state_id = st.stay_state_id
WHERE rr.reservation_id = @ReservationId;

PRINT '4. Reserve an additional service. A service charge is generated immediately.';
EXEC dbo.sp_ReserveService
    @ReservationId = @ReservationId,
    @ServiceId = @ServiceId,
    @ServiceDate = @DemoServiceDate,
    @Quantity = 2,
    @ReservationServiceId = @ReservationServiceId OUTPUT;

SELECT
    rs.reservation_service_id,
    s.name AS service_name,
    rs.service_date,
    rs.quantity,
    rs.unitary_price,
    rss.reservation_service_state_name
FROM dbo.RESERVATION_SERVICES AS rs
INNER JOIN dbo.SERVICES AS s
    ON s.service_id = rs.service_id
INNER JOIN dbo.RESERVATION_SERVICE_STATES AS rss
    ON rss.reservation_service_state_id = rs.reservation_service_state_id
WHERE rs.reservation_id = @ReservationId;

SELECT *
FROM dbo.vw_ReservationCharges
WHERE reservation_id = @ReservationId;

PRINT '5. Execute check-out. Room charges and payment are generated.';
EXEC dbo.sp_CheckOutClient
    @ReservationId = @ReservationId,
    @UserCheckOutId = @UserId,
    @PaymentMethodId = @PaymentMethodId,
    @AmountReceived = NULL;

SELECT *
FROM dbo.vw_ReservationCharges
WHERE reservation_id = @ReservationId;

SELECT
    p.payment_id,
    p.amount,
    p.payment_date,
    pm.payment_method_name,
    ps.payment_state_name
FROM dbo.PAYMENTS AS p
INNER JOIN dbo.PAYMENT_METHODS AS pm
    ON pm.payment_method_id = p.payment_method_id
INNER JOIN dbo.PAYMENT_STATES AS ps
    ON ps.payment_state_id = p.payment_state_id
WHERE p.reservation_id = @ReservationId;

SELECT
    r.reservation_id,
    rs.reservation_state_name,
    rm.room_number,
    rst.state_name AS room_state
FROM dbo.RESERVATIONS AS r
INNER JOIN dbo.RESERVATION_STATES AS rs
    ON rs.reservation_state_id = r.reservation_state_id
INNER JOIN dbo.RESERVATION_ROOMS AS rr
    ON rr.reservation_id = r.reservation_id
INNER JOIN dbo.ROOMS AS rm
    ON rm.room_id = rr.room_id
INNER JOIN dbo.ROOM_STATES AS rst
    ON rst.state_id = rm.state_id
WHERE r.reservation_id = @ReservationId;

PRINT '6. Encrypted backup command for the video demo.';
SELECT
    N'BACKUP DATABASE HotelDatabase TO DISK = ''/backups/HotelDatabase_encrypted.bak'' WITH INIT, COMPRESSION, ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = BackupCertificate_HotelDatabase);' AS encrypted_backup_example;
GO
