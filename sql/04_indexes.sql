USE HotelDatabase;
GO

SET NOCOUNT ON;
GO

CREATE INDEX IX_RESERVATIONS_client_dates
    ON dbo.RESERVATIONS(client_id, check_in_date, check_out_date);

CREATE INDEX IX_RESERVATIONS_state_dates
    ON dbo.RESERVATIONS(reservation_state_id, check_in_date, check_out_date);

CREATE INDEX IX_ROOMS_type_state
    ON dbo.ROOMS(room_type_id, state_id);

CREATE INDEX IX_RESERVATION_ROOMS_room_reservation
    ON dbo.RESERVATION_ROOMS(room_id, reservation_id);

CREATE INDEX IX_RESERVATION_SERVICES_reservation_date
    ON dbo.RESERVATION_SERVICES(reservation_id, service_date);

CREATE INDEX IX_RESERVATION_SERVICES_service_date
    ON dbo.RESERVATION_SERVICES(service_id, service_date);

CREATE INDEX IX_CHARGES_reservation
    ON dbo.CHARGES(reservation_id, charge_type_id);

CREATE INDEX IX_PAYMENTS_reservation
    ON dbo.PAYMENTS(reservation_id, payment_state_id);
GO
