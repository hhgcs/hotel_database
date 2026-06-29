USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'HotelMasterKey#2026!';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'BackupCertificate_HotelDatabase')
BEGIN
    CREATE CERTIFICATE BackupCertificate_HotelDatabase
        WITH SUBJECT = N'HotelDatabase encrypted backup certificate',
             EXPIRY_DATE = '20361231';
END;
GO

USE HotelDatabase;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'HotelDatabaseMasterKey#2026!';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'Certificate_HotelClientData')
BEGIN
    CREATE CERTIFICATE Certificate_HotelClientData
        WITH SUBJECT = N'Hotel client data encryption certificate',
             EXPIRY_DATE = '20361231';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'SymmetricKey_HotelClientData')
BEGIN
    CREATE SYMMETRIC KEY SymmetricKey_HotelClientData
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE Certificate_HotelClientData;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_EmailHash
(
    @email NVARCHAR(320)
)
RETURNS VARBINARY(32)
AS
BEGIN
    RETURN HASHBYTES
    (
        'SHA2_256',
        CONVERT(VARBINARY(MAX), LOWER(LTRIM(RTRIM(@email))))
    );
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_PasswordHash
(
    @password NVARCHAR(4000),
    @salt VARBINARY(16)
)
RETURNS VARBINARY(32)
AS
BEGIN
    RETURN HASHBYTES
    (
        'SHA2_256',
        @salt + CONVERT(VARBINARY(MAX), @password)
    );
END;
GO

/*
Encrypted backup example for the demo:

BACKUP DATABASE HotelDatabase
TO DISK = '/backups/HotelDatabase_encrypted.bak'
WITH INIT,
     COMPRESSION,
     ENCRYPTION
     (
        ALGORITHM = AES_256,
        SERVER CERTIFICATE = BackupCertificate_HotelDatabase
     );

In a real deployment, back up the certificate and private key separately.
*/
GO
