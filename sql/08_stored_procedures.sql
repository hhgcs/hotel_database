USE HotelDatabase;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreateClient
    @FirstName NVARCHAR(80),
    @LastName NVARCHAR(80),
    @Email NVARCHAR(320),
    @PhoneNumber NVARCHAR(40) = NULL,
    @ClientId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@FirstName)), N'') IS NULL
            THROW 52000, 'First name is required.', 1;

        IF NULLIF(LTRIM(RTRIM(@LastName)), N'') IS NULL
            THROW 52001, 'Last name is required.', 1;

        IF NULLIF(LTRIM(RTRIM(@Email)), N'') IS NULL
            THROW 52002, 'Email is required.', 1;

        IF EXISTS (SELECT 1 FROM dbo.CLIENT WHERE email_hash = dbo.fn_EmailHash(@Email))
            THROW 52003, 'A client with that email already exists.', 1;

        BEGIN TRANSACTION;

        OPEN SYMMETRIC KEY SymmetricKey_HotelClientData
            DECRYPTION BY CERTIFICATE Certificate_HotelClientData;

        INSERT dbo.CLIENT
        (
            first_name,
            last_name,
            email_encrypted,
            email_hash,
            phone_number_encrypted
        )
        VALUES
        (
            LTRIM(RTRIM(@FirstName)),
            LTRIM(RTRIM(@LastName)),
            EncryptByKey(Key_GUID(N'SymmetricKey_HotelClientData'), LOWER(LTRIM(RTRIM(@Email)))),
            dbo.fn_EmailHash(@Email),
            CASE
                WHEN @PhoneNumber IS NULL THEN NULL
                ELSE EncryptByKey(Key_GUID(N'SymmetricKey_HotelClientData'), LTRIM(RTRIM(@PhoneNumber)))
            END
        );

        SET @ClientId = CONVERT(INT, SCOPE_IDENTITY());

        CLOSE SYMMETRIC KEY SymmetricKey_HotelClientData;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = N'SymmetricKey_HotelClientData')
            CLOSE SYMMETRIC KEY SymmetricKey_HotelClientData;

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreateUser
    @FirstName NVARCHAR(80),
    @LastName NVARCHAR(80),
    @Email NVARCHAR(320),
    @Username NVARCHAR(60),
    @Password NVARCHAR(4000),
    @RoleName NVARCHAR(60),
    @UserId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RoleId INT = (SELECT role_id FROM dbo.ROLES WHERE rol_name = @RoleName);
    DECLARE @Salt VARBINARY(16) = CRYPT_GEN_RANDOM(16);

    IF @RoleId IS NULL
        THROW 52010, 'Role does not exist.', 1;

    IF EXISTS (SELECT 1 FROM dbo.USERS WHERE username = @Username)
        THROW 52011, 'Username already exists.', 1;

    IF EXISTS (SELECT 1 FROM dbo.USERS WHERE email = @Email)
        THROW 52012, 'User email already exists.', 1;

    INSERT dbo.USERS
    (
        first_name,
        last_name,
        email,
        salt,
        role_id,
        password_hash,
        username
    )
    VALUES
    (
        LTRIM(RTRIM(@FirstName)),
        LTRIM(RTRIM(@LastName)),
        LOWER(LTRIM(RTRIM(@Email))),
        @Salt,
        @RoleId,
        dbo.fn_PasswordHash(@Password, @Salt),
        LTRIM(RTRIM(@Username))
    );

    SET @UserId = CONVERT(INT, SCOPE_IDENTITY());
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CreateReservation
    @ClientId INT,
    @CheckInDate DATE,
    @CheckOutDate DATE,
    @RoomTypeId INT = NULL,
    @ReservationId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ConfirmedStateId INT =
        (SELECT reservation_state_id FROM dbo.RESERVATION_STATES WHERE reservation_state_name = N'Confirmed');

    DECLARE @RoomId INT;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.CLIENT WHERE client_id = @ClientId)
            THROW 52020, 'Client does not exist.', 1;

        IF @CheckOutDate <= @CheckInDate
            THROW 52021, 'Check-out date must be after check-in date.', 1;

        IF @ConfirmedStateId IS NULL
            THROW 52022, 'Confirmed reservation state is missing.', 1;

        SELECT TOP (1) @RoomId = rm.room_id
        FROM dbo.ROOMS AS rm
        INNER JOIN dbo.ROOM_STATES AS rst
            ON rst.state_id = rm.state_id
        WHERE rst.state_name <> N'Maintenance'
          AND (@RoomTypeId IS NULL OR rm.room_type_id = @RoomTypeId)
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.RESERVATION_ROOMS AS rr
              INNER JOIN dbo.RESERVATIONS AS r
                  ON r.reservation_id = rr.reservation_id
              INNER JOIN dbo.RESERVATION_STATES AS rs
                  ON rs.reservation_state_id = r.reservation_state_id
              WHERE rr.room_id = rm.room_id
                AND rs.reservation_state_name IN (N'Pending', N'Confirmed', N'InProgress')
                AND @CheckInDate < r.check_out_date
                AND @CheckOutDate > r.check_in_date
          )
        ORDER BY rm.room_id;

        IF @RoomId IS NULL
            THROW 52023, 'No available room was found for the requested dates.', 1;

        BEGIN TRANSACTION;

        INSERT dbo.RESERVATIONS(client_id, check_in_date, check_out_date, reservation_state_id)
        VALUES (@ClientId, @CheckInDate, @CheckOutDate, @ConfirmedStateId);

        SET @ReservationId = CONVERT(INT, SCOPE_IDENTITY());

        INSERT dbo.RESERVATION_ROOMS(reservation_id, room_id)
        VALUES (@ReservationId, @RoomId);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CheckInClient
    @ReservationId INT,
    @UserCheckInId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @InProgressStateId INT =
        (SELECT reservation_state_id FROM dbo.RESERVATION_STATES WHERE reservation_state_name = N'InProgress');
    DECLARE @ActiveStayStateId INT =
        (SELECT stay_state_id FROM dbo.STAY_STATES WHERE stay_state_name = N'Active');
    DECLARE @OccupiedRoomStateId INT =
        (SELECT state_id FROM dbo.ROOM_STATES WHERE state_name = N'Occupied');

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.USERS WHERE user_id = @UserCheckInId AND active = 1)
            THROW 52030, 'Check-in user does not exist or is inactive.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.RESERVATIONS AS r
            INNER JOIN dbo.RESERVATION_STATES AS rs
                ON rs.reservation_state_id = r.reservation_state_id
            WHERE r.reservation_id = @ReservationId
              AND rs.reservation_state_name IN (N'Pending', N'Confirmed')
        )
        BEGIN
            THROW 52031, 'Reservation must exist and be Pending or Confirmed for check-in.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.STAYS AS s
            INNER JOIN dbo.STAY_STATES AS ss
                ON ss.stay_state_id = s.stay_state_id
            WHERE s.reservation_id = @ReservationId
              AND ss.stay_state_name = N'Active'
        )
        BEGIN
            THROW 52032, 'Reservation is already checked in.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.RESERVATION_ROOMS WHERE reservation_id = @ReservationId)
            THROW 52033, 'Reservation has no assigned rooms.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.RESERVATION_ROOMS AS rr
            INNER JOIN dbo.ROOMS AS rm
                ON rm.room_id = rr.room_id
            INNER JOIN dbo.ROOM_STATES AS rst
                ON rst.state_id = rm.state_id
            WHERE rr.reservation_id = @ReservationId
              AND rst.state_name = N'Maintenance'
        )
        BEGIN
            THROW 52034, 'A room assigned to this reservation is in maintenance.', 1;
        END;

        BEGIN TRANSACTION;

        INSERT dbo.STAYS
        (
            reservation_id,
            check_in_date,
            user_check_in_id,
            stay_state_id
        )
        VALUES
        (
            @ReservationId,
            SYSDATETIME(),
            @UserCheckInId,
            @ActiveStayStateId
        );

        UPDATE dbo.RESERVATIONS
        SET reservation_state_id = @InProgressStateId
        WHERE reservation_id = @ReservationId;

        UPDATE rm
        SET state_id = @OccupiedRoomStateId
        FROM dbo.ROOMS AS rm
        INNER JOIN dbo.RESERVATION_ROOMS AS rr
            ON rr.room_id = rm.room_id
        WHERE rr.reservation_id = @ReservationId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ReserveService
    @ReservationId INT,
    @ServiceId INT,
    @ServiceDate DATETIME2(0),
    @Quantity INT,
    @ReservationServiceId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ReservedStateId INT =
        (SELECT reservation_service_state_id FROM dbo.RESERVATION_SERVICE_STATES WHERE reservation_service_state_name = N'Reserved');
    DECLARE @ServiceChargeTypeId INT =
        (SELECT charge_type_id FROM dbo.CHARGE_TYPES WHERE name = N'Service');
    DECLARE @ServicePrice DECIMAL(10,2);
    DECLARE @ServiceCapacity INT;
    DECLARE @Subtotal DECIMAL(10,2);
    DECLARE @Taxes DECIMAL(10,2);
    DECLARE @TaxRate DECIMAL(5,4) = 0.1600;

    BEGIN TRY
        IF @Quantity <= 0
            THROW 52040, 'Service quantity must be greater than zero.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.RESERVATIONS AS r
            INNER JOIN dbo.RESERVATION_STATES AS rs
                ON rs.reservation_state_id = r.reservation_state_id
            WHERE r.reservation_id = @ReservationId
              AND rs.reservation_state_name IN (N'Confirmed', N'InProgress')
              AND CONVERT(DATE, @ServiceDate) >= r.check_in_date
              AND CONVERT(DATE, @ServiceDate) < r.check_out_date
        )
        BEGIN
            THROW 52041, 'Reservation must be Confirmed or InProgress and service date must be inside reservation dates.', 1;
        END;

        SELECT
            @ServicePrice = price,
            @ServiceCapacity = capacity
        FROM dbo.SERVICES
        WHERE service_id = @ServiceId
          AND availability = 1;

        IF @ServicePrice IS NULL
            THROW 52042, 'Service does not exist or is unavailable.', 1;

        IF @ServiceCapacity > 0
        BEGIN
            DECLARE @AlreadyReserved INT =
            (
                SELECT ISNULL(SUM(rs.quantity), 0)
                FROM dbo.RESERVATION_SERVICES AS rs
                INNER JOIN dbo.RESERVATION_SERVICE_STATES AS rss
                    ON rss.reservation_service_state_id = rs.reservation_service_state_id
                WHERE rs.service_id = @ServiceId
                  AND CONVERT(DATE, rs.service_date) = CONVERT(DATE, @ServiceDate)
                  AND rss.reservation_service_state_name <> N'Cancelled'
            );

            IF @AlreadyReserved + @Quantity > @ServiceCapacity
                THROW 52043, 'Service capacity exceeded for the selected date.', 1;
        END;

        SET @Subtotal = @Quantity * @ServicePrice;
        SET @Taxes = ROUND(@Subtotal * @TaxRate, 2);

        BEGIN TRANSACTION;

        INSERT dbo.RESERVATION_SERVICES
        (
            reservation_id,
            service_id,
            service_date,
            quantity,
            unitary_price,
            reservation_service_state_id
        )
        VALUES
        (
            @ReservationId,
            @ServiceId,
            @ServiceDate,
            @Quantity,
            @ServicePrice,
            @ReservedStateId
        );

        SET @ReservationServiceId = CONVERT(INT, SCOPE_IDENTITY());

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
            total
        )
        VALUES
        (
            @ReservationId,
            @ServiceChargeTypeId,
            @ReservationServiceId,
            N'Service charge',
            @Quantity,
            @ServicePrice,
            @Subtotal,
            @Taxes,
            @Subtotal + @Taxes
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_CheckOutClient
    @ReservationId INT,
    @UserCheckOutId INT,
    @PaymentMethodId INT,
    @AmountReceived DECIMAL(10,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FinishedReservationStateId INT =
        (SELECT reservation_state_id FROM dbo.RESERVATION_STATES WHERE reservation_state_name = N'Finished');
    DECLARE @FinishedStayStateId INT =
        (SELECT stay_state_id FROM dbo.STAY_STATES WHERE stay_state_name = N'Finished');
    DECLARE @CleaningRoomStateId INT =
        (SELECT state_id FROM dbo.ROOM_STATES WHERE state_name = N'Cleaning');
    DECLARE @RoomChargeTypeId INT =
        (SELECT charge_type_id FROM dbo.CHARGE_TYPES WHERE name = N'Room');
    DECLARE @PaidStateId INT =
        (SELECT payment_state_id FROM dbo.PAYMENT_STATES WHERE payment_state_name = N'Paid');
    DECLARE @TaxRate DECIMAL(5,4) = 0.1600;
    DECLARE @Balance DECIMAL(10,2);
    DECLARE @PaymentAmount DECIMAL(10,2);

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.USERS WHERE user_id = @UserCheckOutId AND active = 1)
            THROW 52050, 'Check-out user does not exist or is inactive.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.PAYMENT_METHODS WHERE payment_method_id = @PaymentMethodId)
            THROW 52051, 'Payment method does not exist.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.RESERVATIONS AS r
            INNER JOIN dbo.RESERVATION_STATES AS rs
                ON rs.reservation_state_id = r.reservation_state_id
            INNER JOIN dbo.STAYS AS s
                ON s.reservation_id = r.reservation_id
            INNER JOIN dbo.STAY_STATES AS ss
                ON ss.stay_state_id = s.stay_state_id
            WHERE r.reservation_id = @ReservationId
              AND rs.reservation_state_name = N'InProgress'
              AND ss.stay_state_name = N'Active'
              AND s.check_out_date IS NULL
        )
        BEGIN
            THROW 52052, 'Reservation must be checked in and active for check-out.', 1;
        END;

        BEGIN TRANSACTION;

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
            total
        )
        SELECT
            r.reservation_id,
            @RoomChargeTypeId,
            rr.reservation_room_id,
            CONCAT(N'Room charge - room ', rm.room_number),
            CASE WHEN DATEDIFF(DAY, r.check_in_date, r.check_out_date) < 1 THEN 1 ELSE DATEDIFF(DAY, r.check_in_date, r.check_out_date) END,
            rt.price,
            CASE WHEN DATEDIFF(DAY, r.check_in_date, r.check_out_date) < 1 THEN 1 ELSE DATEDIFF(DAY, r.check_in_date, r.check_out_date) END * rt.price,
            ROUND((CASE WHEN DATEDIFF(DAY, r.check_in_date, r.check_out_date) < 1 THEN 1 ELSE DATEDIFF(DAY, r.check_in_date, r.check_out_date) END * rt.price) * @TaxRate, 2),
            (CASE WHEN DATEDIFF(DAY, r.check_in_date, r.check_out_date) < 1 THEN 1 ELSE DATEDIFF(DAY, r.check_in_date, r.check_out_date) END * rt.price)
                + ROUND((CASE WHEN DATEDIFF(DAY, r.check_in_date, r.check_out_date) < 1 THEN 1 ELSE DATEDIFF(DAY, r.check_in_date, r.check_out_date) END * rt.price) * @TaxRate, 2)
        FROM dbo.RESERVATIONS AS r
        INNER JOIN dbo.RESERVATION_ROOMS AS rr
            ON rr.reservation_id = r.reservation_id
        INNER JOIN dbo.ROOMS AS rm
            ON rm.room_id = rr.room_id
        INNER JOIN dbo.ROOM_TYPES AS rt
            ON rt.room_type_id = rm.room_type_id
        WHERE r.reservation_id = @ReservationId
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.CHARGES AS ch
              WHERE ch.reservation_room_id = rr.reservation_room_id
                AND ch.charge_type_id = @RoomChargeTypeId
          );

        SELECT @Balance =
            ISNULL(SUM(ch.total), 0)
            - ISNULL
            (
                (
                    SELECT SUM(p.amount)
                    FROM dbo.PAYMENTS AS p
                    INNER JOIN dbo.PAYMENT_STATES AS ps
                        ON ps.payment_state_id = p.payment_state_id
                    WHERE p.reservation_id = @ReservationId
                      AND ps.payment_state_name = N'Paid'
                ),
                0
            )
        FROM dbo.CHARGES AS ch
        WHERE ch.reservation_id = @ReservationId;

        SET @PaymentAmount = ISNULL(@AmountReceived, @Balance);

        IF @PaymentAmount < @Balance
            THROW 52053, 'Payment amount is lower than the reservation balance.', 1;

        IF @PaymentAmount > @Balance
            SET @PaymentAmount = @Balance;

        IF @PaymentAmount <= 0
            THROW 52054, 'Reservation balance must be greater than zero to process payment.', 1;

        INSERT dbo.PAYMENTS
        (
            reservation_id,
            amount,
            payment_method_id,
            payment_state_id
        )
        VALUES
        (
            @ReservationId,
            @PaymentAmount,
            @PaymentMethodId,
            @PaidStateId
        );

        UPDATE dbo.STAYS
        SET check_out_date = SYSDATETIME(),
            user_check_out_id = @UserCheckOutId,
            stay_state_id = @FinishedStayStateId
        WHERE reservation_id = @ReservationId;

        UPDATE dbo.RESERVATIONS
        SET reservation_state_id = @FinishedReservationStateId
        WHERE reservation_id = @ReservationId;

        UPDATE rm
        SET state_id = @CleaningRoomStateId
        FROM dbo.ROOMS AS rm
        INNER JOIN dbo.RESERVATION_ROOMS AS rr
            ON rr.room_id = rm.room_id
        WHERE rr.reservation_id = @ReservationId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
