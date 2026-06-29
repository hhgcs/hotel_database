USE HotelDatabase;
GO

DROP VIEW IF EXISTS dbo.vw_ClientHistory;
DROP VIEW IF EXISTS dbo.vw_PaymentSummary;
GO

CREATE OR ALTER VIEW dbo.vw_ActiveReservations
AS
SELECT
    r.reservation_id,
    r.client_id,
    c.first_name,
    c.last_name,
    CONVERT(VARCHAR(64), c.email_hash, 2) AS email_hash_hex,
    r.check_in_date,
    r.check_out_date,
    rs.reservation_state_name,
    COUNT(rr.reservation_room_id) AS assigned_rooms
FROM dbo.RESERVATIONS AS r
INNER JOIN dbo.CLIENT AS c
    ON c.client_id = r.client_id
INNER JOIN dbo.RESERVATION_STATES AS rs
    ON rs.reservation_state_id = r.reservation_state_id
LEFT JOIN dbo.RESERVATION_ROOMS AS rr
    ON rr.reservation_id = r.reservation_id
WHERE rs.reservation_state_name IN (N'Pending', N'Confirmed', N'InProgress')
GROUP BY
    r.reservation_id,
    r.client_id,
    c.first_name,
    c.last_name,
    c.email_hash,
    r.check_in_date,
    r.check_out_date,
    rs.reservation_state_name;
GO

CREATE OR ALTER VIEW dbo.vw_RoomAvailability
AS
SELECT
    rm.room_id,
    rm.room_number,
    rm.room_floor,
    rt.name AS room_type,
    rt.capacity,
    rt.price,
    rst.state_name AS current_room_state,
    MIN(CASE
        WHEN r.check_in_date >= CONVERT(DATE, SYSDATETIME()) THEN r.check_in_date
        ELSE NULL
    END) AS next_reserved_date
FROM dbo.ROOMS AS rm
INNER JOIN dbo.ROOM_TYPES AS rt
    ON rt.room_type_id = rm.room_type_id
INNER JOIN dbo.ROOM_STATES AS rst
    ON rst.state_id = rm.state_id
LEFT JOIN dbo.RESERVATION_ROOMS AS rr
    ON rr.room_id = rm.room_id
LEFT JOIN dbo.RESERVATIONS AS r
    ON r.reservation_id = rr.reservation_id
LEFT JOIN dbo.RESERVATION_STATES AS rs
    ON rs.reservation_state_id = r.reservation_state_id
    AND rs.reservation_state_name IN (N'Pending', N'Confirmed', N'InProgress')
GROUP BY
    rm.room_id,
    rm.room_number,
    rm.room_floor,
    rt.name,
    rt.capacity,
    rt.price,
    rst.state_name;
GO

CREATE OR ALTER VIEW dbo.vw_ReservationCharges
AS
SELECT
    r.reservation_id,
    r.client_id,
    SUM(ISNULL(ch.subtotal, 0)) AS subtotal,
    SUM(ISNULL(ch.taxes, 0)) AS taxes,
    SUM(ISNULL(ch.total, 0)) AS total_charges,
    ISNULL(paid.total_paid, 0) AS total_paid,
    SUM(ISNULL(ch.total, 0)) - ISNULL(paid.total_paid, 0) AS balance
FROM dbo.RESERVATIONS AS r
LEFT JOIN dbo.CHARGES AS ch
    ON ch.reservation_id = r.reservation_id
OUTER APPLY
(
    SELECT SUM(p.amount) AS total_paid
    FROM dbo.PAYMENTS AS p
    INNER JOIN dbo.PAYMENT_STATES AS ps
        ON ps.payment_state_id = p.payment_state_id
    WHERE p.reservation_id = r.reservation_id
      AND ps.payment_state_name = N'Paid'
) AS paid
GROUP BY
    r.reservation_id,
    r.client_id,
    paid.total_paid;
GO
