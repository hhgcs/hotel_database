USE HotelDatabase;
GO

CREATE OR ALTER TRIGGER dbo.trg_CLIENT_EncryptionGuard
ON dbo.CLIENT
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE email_hash IS NULL
           OR DATALENGTH(email_hash) <> 32
           OR email_encrypted IS NULL
           OR DATALENGTH(email_encrypted) < 32
           OR (phone_number_encrypted IS NOT NULL AND DATALENGTH(phone_number_encrypted) < 32)
    )
    BEGIN
        THROW 51000, 'CLIENT confidential columns must be encrypted and email_hash must be SHA-256 length.', 1;
    END;

    DECLARE @OpenedKey BIT = 0;

    BEGIN TRY
        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.openkeys
            WHERE key_name = N'SymmetricKey_HotelClientData'
        )
        BEGIN
            OPEN SYMMETRIC KEY SymmetricKey_HotelClientData
                DECRYPTION BY CERTIFICATE Certificate_HotelClientData;

            SET @OpenedKey = 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM inserted AS i
            CROSS APPLY
            (
                VALUES
                (
                    CONVERT(NVARCHAR(320), DecryptByKey(i.email_encrypted)),
                    CASE
                        WHEN i.phone_number_encrypted IS NULL THEN NULL
                        ELSE CONVERT(NVARCHAR(40), DecryptByKey(i.phone_number_encrypted))
                    END
                )
            ) AS decrypted(email_value, phone_value)
            WHERE decrypted.email_value IS NULL
               OR dbo.fn_EmailHash(decrypted.email_value) <> i.email_hash
               OR (i.phone_number_encrypted IS NOT NULL AND decrypted.phone_value IS NULL)
        )
        BEGIN
            IF @OpenedKey = 1
                CLOSE SYMMETRIC KEY SymmetricKey_HotelClientData;

            THROW 51003, 'CLIENT confidential columns must be valid encrypted values and email_hash must match the encrypted email.', 1;
        END;

        IF @OpenedKey = 1
            CLOSE SYMMETRIC KEY SymmetricKey_HotelClientData;
    END TRY
    BEGIN CATCH
        IF @OpenedKey = 1
           AND EXISTS
           (
                SELECT 1
                FROM sys.openkeys
                WHERE key_name = N'SymmetricKey_HotelClientData'
           )
        BEGIN
            CLOSE SYMMETRIC KEY SymmetricKey_HotelClientData;
        END;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_RESERVATION_ROOMS_Integrity
ON dbo.RESERVATION_ROOMS
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.ROOMS AS rm
            ON rm.room_id = i.room_id
        INNER JOIN dbo.ROOM_STATES AS rst
            ON rst.state_id = rm.state_id
        WHERE rst.state_name = N'Maintenance'
    )
    BEGIN
        THROW 51001, 'A room in maintenance cannot be assigned to a reservation.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.RESERVATIONS AS new_res
            ON new_res.reservation_id = i.reservation_id
        INNER JOIN dbo.RESERVATION_STATES AS new_state
            ON new_state.reservation_state_id = new_res.reservation_state_id
        INNER JOIN dbo.RESERVATION_ROOMS AS existing_rr
            ON existing_rr.room_id = i.room_id
           AND existing_rr.reservation_room_id <> i.reservation_room_id
        INNER JOIN dbo.RESERVATIONS AS existing_res
            ON existing_res.reservation_id = existing_rr.reservation_id
        INNER JOIN dbo.RESERVATION_STATES AS existing_state
            ON existing_state.reservation_state_id = existing_res.reservation_state_id
        WHERE new_state.reservation_state_name IN (N'Pending', N'Confirmed', N'InProgress')
          AND existing_state.reservation_state_name IN (N'Pending', N'Confirmed', N'InProgress')
          AND new_res.check_in_date < existing_res.check_out_date
          AND new_res.check_out_date > existing_res.check_in_date
    )
    BEGIN
        THROW 51002, 'The room is already assigned to an overlapping active reservation.', 1;
    END;
END;
GO
