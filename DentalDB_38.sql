
CREATE DATABASE DentalDB_38
GO

USE DentalDB_38
GO

---------------------PROCEDURES-------------------------------------------------------
/*
Display detailed receipt
DROP PROCEDURE spDisplayReciept
*/
CREATE PROCEDURE spDisplayReciept
@odr_id INT
AS
BEGIN
	DECLARE @order_id AS INT
	DECLARE @patient_id INT
	DECLARE @patient_surname nvarchar(25)
	DECLARE @patient_name nvarchar(25)
	DECLARE @line_qty INT
	DECLARE @order_date DATE
	DECLARE @order_time TIME
	DECLARE @dob DATE
	DECLARE @counter INT
	DECLARE @line_of_symbols NVARCHAR(100) = '*'
	DECLARE @payment_status BIT
	DECLARE @payment_card_type NVARCHAR(25)
	DECLARE @Payment_card_exp date
	DECLARE @status NVARCHAR(25)

	SELECT @counter = COUNT(order_id)
		FROM Orders
		WHERE order_id = @odr_id

	IF @counter = 0 
		BEGIN
			PRINT REPLICATE(@line_of_symbols , 50 ) 
			PRINT CONCAT('No data in Database for order with ID = ', @odr_id)
			PRINT REPLICATE(@line_of_symbols , 50 ) 
		END
	ELSE
		BEGIN
		IF @payment_status = 0
			SET @status = 'PAID'
		ELSE
			SET @status = 'IN PROCESS'
			SET @counter = 0
			---Collect data for reciept
			SELECT @order_id = odr.order_id, @patient_id = odr.patient_id, @patient_surname = ptn.surname, @dob = ptn.dob,
					@patient_name = ptn.name, @line_qty = COUNT(line.line_id), @order_date = order_date, @order_time = order_time,
					@payment_status = odr.paystatus, @payment_card_type = card.card_type, @Payment_card_exp = card.expired_on  
			FROM Orders AS odr
			INNER JOIN OrderLines AS line
			ON odr.order_id = line.order_id
			INNER JOIN Patients AS ptn
			ON odr.patient_id = ptn.patient_id
			INNER JOIN PayCards AS card
			ON odr.paycard_id = card.paycard_id
			WHERE odr.order_id = @odr_id
			GROUP BY odr.order_id, odr.patient_id, ptn.surname, ptn.name, 
			odr.order_date, odr.order_time, ptn.dob, card.card_type, card.expired_on, odr.paystatus
		
			PRINT REPLICATE(@line_of_symbols , 50 ) 
			PRINT 'Order details:'
			PRINT ''
			PRINT CONCAT('Order ID                     = ', @order_id)
			PRINT CONCAT('Patient ID                   = ', @patient_id)
			PRINT CONCAT(CONCAT('Patient Surname and Name     = ', (@patient_surname), ' '), @patient_name)
			PRINT CONCAT('DOB                          = ', CONVERT(varchar, @dob, 107))
			PRINT CONCAT('Qty of services              = ', dbo.GetQtyOfPatientOrderLines(@patient_id))
			PRINT CONCAT('Total price with no discount = ', dbo.GetPriceNoDiscount(@order_id))
			PRINT CONCAT('Percentage of discount       = ', dbo.GetPatientDiscount(@patient_id), '%')
			PRINT CONCAT('Total price with discount    = ', dbo.GetPriceWithDiscount(@order_id))
			PRINT CONCAT('Saved                        = ', (dbo.GetPriceNoDiscount(@order_id) - dbo.GetPriceWithDiscount(@order_id)))
			PRINT CONCAT('Payment card type            = ', @payment_card_type)
			PRINT CONCAT('Payment card expired on      = ', @Payment_card_exp)			
			PRINT CONCAT('Payment status               = ', @status)
			PRINT CONCAT('Order created on             = ', CONVERT(varchar, @order_date, 107)) 
			PRINT CONCAT('Order created at             = ', CONVERT(varchar, @order_time, 108))
			PRINT REPLICATE(@line_of_symbols , 50 ) 
		END	
END
GO
---------------------END OF PROCEDURES-----------------

---------------------FUNCTIONS--------------------------
/*
DROP FUNCTION CheckEmail
*/
CREATE FUNCTION CheckEmail (@email NVARCHAR(255))
RETURNS INT
AS
BEGIN
	IF @email IS NOT NULL
		BEGIN
		    ---RegExpr source https://self-learning.ru/��������-email-��-����������-�-microsoft-sql-server-��-t-sql
			IF @email LIKE '%[A-Z0-9][@][A-Z0-9]%[.][A-Z0-9]%' AND @email NOT LIKE '%["<>'']%'
			RETURN 1			
		END
	RETURN 0
END
GO

/*
Get the quantity of the patient's visits
DROP FUNCTION GetQtyOfPatientOrderLines
*/
CREATE FUNCTION GetQtyOfPatientOrderLines (@patient_id INT)
RETURNS INT
AS
BEGIN
	RETURN (SELECT COUNT(*)
				FROM OrderLines AS Lines
				INNER JOIN Orders AS Orders
				ON Lines.order_id = Orders.order_id
				WHERE Orders.patient_id = @patient_id)
END
GO

/*
Discount is in %
DROP FUNCTION GetPatientDiscount
*/
CREATE FUNCTION GetPatientDiscount (@patient_id INT)
RETURNS INT
AS 
BEGIN
	DECLARE @qty_visit INT;

	SET @qty_visit = dbo.GetQtyOfPatientOrderLines(@patient_id)
	RETURN CASE 
				WHEN @qty_visit < 3 THEN 5
				WHEN @qty_visit < 5 THEN 10
				WHEN @qty_visit < 7 THEN 15
				ELSE 20
		   END	
END
GO

/*
Collect the sum of money that the patient spent for the distinct order
including the discount in %
DROP FUNCTION GetTotalPrice
*/
CREATE FUNCTION GetPriceWithDiscount (@order_id INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
	DECLARE @price DECIMAL(5,2)
	DECLARE @discount INT
	DECLARE @patient_id INT

	SELECT @price = SUM(price), @patient_id = patient_id
		FROM Orders
		INNER JOIN OrderLines
		ON Orders.order_id = OrderLines.order_id
		INNER JOIN DentalServices
		ON OrderLines.service_id = DentalServices.service_id
		WHERE Orders.order_id = @order_id
		GROUP BY patient_id

	SET @discount = dbo.GetPatientDiscount(@patient_id)

	IF @discount > 0 
		RETURN  (@price - ((@price * CAST(@discount AS DECIMAL(5,2))) / 100));
		
	RETURN @price
END
GO

/*
DROP FUNCTION GetPriceNoDiscount
*/
CREATE FUNCTION GetPriceNoDiscount (@order_id INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
	RETURN (SELECT SUM(price)
		FROM Orders
		INNER JOIN OrderLines
		ON Orders.order_id = OrderLines.order_id
		INNER JOIN DentalServices
		ON OrderLines.service_id = DentalServices.service_id
		WHERE Orders.order_id = @order_id)
END
GO

--------------------END OF FUNCTIONS--------------------

--------------------CREATE TABLES-----------------------

/*
Dental clinics patients' info  
DROP TABLE Patients
*/
CREATE /*COLUMN*/ TABLE Patients
(
	patient_id INT NOT NULL IDENTITY(1,1), 
	surname NVARCHAR(25) NOT NULL,
	name nvarchar(25) NOT NULL,
	patronimic NVARCHAR(25) NOT NULL DEFAULT '',
	dob DATE NOT NULL CHECK (dob > '1900.01.01' AND dob < '2150.01.01'),
	email NVARCHAR(50) NOT NULL CHECK (dbo.CheckEmail(email) = 1) UNIQUE,
	phone NVARCHAR(12) NOT NULL CHECK (Phone LIKE '([0-9][0-9][0-9])[0-9][0-9][0-9][0-9][0-9][0-9][0-9]') UNIQUE,
	PRIMARY KEY(patient_id)
)
GO

/*
Table of banks' cards used in payments
DROP TABLE PayCards
*/
CREATE /*COLUMN*/ TABLE PayCards
(
	paycard_id INT NOT NULL IDENTITY(1,1),
	card_number NVARCHAR(16) NOT NULL CHECK (card_number LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]') UNIQUE,
	card_type NVARCHAR(25) NOT NULL DEFAULT 'n\a',
	owner_surname NVARCHAR(25) NOT NULL DEFAULT 'n\a',
	owner_name NVARCHAR(25) NOT NULL DEFAULT 'n\a',
	expired_on date NOT NULL CHECK (expired_on >= GETDATE()),
	PRIMARY KEY (paycard_id)
)
GO

/*
Positions that are available at the clinics 
DROP TABLE Ocupations
*/
CREATE /*COLUMN*/ TABLE Ocupations
(
	ocupation_id INT NOT NULL IDENTITY(1,1),  
	title NVARCHAR(50) UNIQUE,
	PRIMARY KEY(ocupation_id)	
)
GO

/*
Employees' info
DROP TABLE Employees
*/
CREATE /*COLUMN*/ TABLE Employees
(
	employee_id INT NOT NULL IDENTITY(1,1),  
	ocupation_id INT NOT NULL,
	surname NVARCHAR(25) NOT NULL,
	name NVARCHAR(25) NOT NULL,
	patronimic NVARCHAR(25) NOT NULL DEFAULT '',
    dob DATE NOT NULL CHECK (dob > '1900.01.01' AND dob < '2150.01.01'),	
	email NVARCHAR(255) NOT NULL CHECK (dbo.CheckEmail(email) = 1) UNIQUE,	
	phone NVARCHAR(12) NOT NULL CHECK (Phone LIKE '([0-9][0-9][0-9])[0-9][0-9][0-9][0-9][0-9][0-9][0-9]') UNIQUE,
	PRIMARY KEY (employee_id),
	FOREIGN KEY (ocupation_id) REFERENCES Ocupations(ocupation_id) ON DELETE CASCADE
)
GO

/*
available  services 
DROP TABLE DentalServices 
*/
CREATE /*COLUMN*/ TABLE DentalServices 
(
	service_id INT NOT NULL IDENTITY(1,1),  
	ocupation_id INT NOT NULL, 
	description NVARCHAR(100) NOT NULL UNIQUE,
	price DECIMAL(8,2) NOT NULL DEFAULT '0.00',
	PRIMARY  KEY(service_id),
	FOREIGN KEY(ocupation_id) REFERENCES Ocupations(ocupation_id) ON DELETE CASCADE
)
GO

/*
List of orders
DROP TABLE Orders
*/
CREATE /*COLUMN*/ TABLE Orders
(
	order_id INT NOT NULL IDENTITY(1,1),  
	patient_id INT NOT NULL,
	paycard_id INT NOT NULL, 
	paystatus BIT NOT NULL DEFAULT 0,	
	order_date DATE NOT NULL DEFAULT GETDATE(),
	order_time TIME NOT NULL DEFAULT CURRENT_TIMESTAMP, 	
	PRIMARY KEY(order_id),
	FOREIGN KEY(patient_id) REFERENCES Patients(patient_id) ON DELETE CASCADE,
	FOREIGN KEY(paycard_id) REFERENCES PayCards(paycard_id) ON DELETE CASCADE
)
GO 

/*
List of order's items
DROP TABLE OrderLines
*/
CREATE /*COLUMN*/ TABLE OrderLines
(
	order_id INT NOT NULL,  
	line_id INT NOT NULL,    
	service_id INT NOT NULL, 
	detail_date DATE NOT NULL DEFAULT GETDATE() ,
	detail_time TIME NOT NULL DEFAULT CURRENT_TIMESTAMP, 
	PRIMARY KEY(order_id, line_id),
	FOREIGN KEY(order_id) REFERENCES Orders(order_id) ON DELETE CASCADE,
	FOREIGN KEY(service_id) REFERENCES DentalServices(service_id) ON DELETE CASCADE
)
GO 
---------------------END OF TABLES-------------------------------------------

--------------------TRIGGERS-----------------------------
/*
Set auto increment to column line_id of table OrderLines
DROP TRIGGER Instead_Trigger
*/
CREATE TRIGGER Instead_Trigger
ON OrderLines
INSTEAD OF INSERT
AS
BEGIN
	---declare local vars
	DECLARE @order_id INT
	DECLARE @line_id INT
	DECLARE @service_id INT
	DECLARE @detail_date DATE
	DECLARE @detail_time TIME
	---get data from the system table
	SELECT @order_id = order_id FROM inserted
	SELECT @service_id = service_id FROM inserted
	SELECT @detail_date = detail_date FROM inserted
	SELECT @detail_time = detail_time FROM inserted
	--check if inserted order_id exists in the table OrderLines
	IF NOT EXISTS (SELECT * FROM OrderLines WHERE order_id = @order_id)
		SET @line_id = 1;
	ELSE
	---increase by one the last inserted line's number 
	SET @line_id = (SELECT MAX(OrderLines.line_id) + 1
						FROM OrderLines
						WHERE OrderLines.order_id = @order_id);
	---change the data in the inserted line
	INSERT INTO OrderLines (order_id, line_id, service_id, detail_date, detail_time)
	VALUES (@order_id, @line_id, @service_id, @detail_date, @detail_time)
END
GO
---------------------END OF TRIGGERS--------------------------------------------------

---------------------FILL THE DATA IN-------------------------------------------------
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Ivanov', 'Tigran', 'Ivanovich', '2000.10.10', 'ivanov.ivan@mail.ru', '(987)3223344');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Tokalenko', 'Sergei', 'Olegovic', '1987.12.01', 'sergej.tokalenko@gmail.com', '(999)9992211');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Belih', 'Artem', 'Bogdanovich', '2007.09.02', 'artem.belih@hotmail.com', '(323)9234352');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Panasenko', 'Igor', 'Ivanovich', '1972.11.21', 'mymail@mail.ru', '(923)2211333');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Andrushko', 'Andrej', 'Borisovich', '1988.08.29', 'admin@ukr.net', '(945)9483724');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Portnoj', 'Kondrat', 'Efimovich', '2001.07.15', 'portnoj@mail.ru', '(878)8844765');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Laptev', 'Kiril', 'Andreevich', '2010.03.22', 'kiril_my@wp.com', '(673)9876567');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Drakery', 'Anna', 'Alekseevna', '2002.04.28', 'order@dtr.net', '(097)4455676');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Kireeva', 'Ekaterina', 'Mikhailovna', '1950.06.24', 'partner@gov.us', '(067)9876879');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Koval', 'Irina', 'Andreevna', '1955.02.26', 'kartmen@qwer.ty', '(789)1233214');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Kovalenko', 'Olga', 'Petrovna', '1999.12.30', 'olga.kovalenko@gmail.com', '(890)8833994');
INSERT INTO Patients (surname, name, patronimic, dob, email, phone) VALUES ('Konovalova', 'Galina', 'Ivanovna', '2009.12.31', 'galina_konovalova@mail.ru', '(674)2323234');
GO

INSERT INTO PayCards (card_number, card_type, owner_surname, owner_name, expired_on)
VALUES ('2022567812345678', 'VISA', 'Parshikov', 'Alex', '2022.09.09')
INSERT INTO PayCards (card_number, card_type, owner_surname, owner_name, expired_on)
VALUES ('2024123443211234', 'VISA', 'Ivanchenko', 'Vadim', '2024.12.31')
INSERT INTO PayCards (card_number, card_type, owner_surname, owner_name, expired_on)
VALUES ('2022123812341234', 'Virtual', '', '', '2022.11.02')
INSERT INTO PayCards (card_number, card_type, owner_surname, owner_name, expired_on)
VALUES ('2022123412341234', 'Virtual', '', '', '2022.11.02')
INSERT INTO PayCards (card_number, card_type, owner_surname, owner_name, expired_on)
VALUES ('2023876545678765', '', '', '', '2023.09.20')
INSERT INTO PayCards (card_number, card_type, owner_surname, owner_name, expired_on)
VALUES ('2024123443211934', 'MASTER', 'Ivanchenko', 'Vadim', '2024.12.31')
INSERT INTO PayCards (card_number, card_type, owner_surname, owner_name, expired_on)
VALUES ('2023876549618765', 'MASTER', '', '', '2023.09.20')
GO

INSERT INTO Ocupations (title) VALUES ('Surgeon');
INSERT INTO Ocupations (title) VALUES ('Dentist');
INSERT INTO Ocupations (title) VALUES ('Nurse');
INSERT INTO Ocupations (title) VALUES ('Dental Hygienist');
INSERT INTO Ocupations (title) VALUES ('Dental Lab Technician');
INSERT INTO Ocupations (title) VALUES ('General Dentist');
INSERT INTO Ocupations (title) VALUES ('Endodontist');
INSERT INTO Ocupations (title) VALUES ('Periodontist');
INSERT INTO Ocupations (title) VALUES ('Dental Anesthesiologist');
INSERT INTO Ocupations (title) VALUES ('Orthodontist');
GO

INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (3, 'Petrov', 'Petr', 'Petrovich', '1997.01.02', '3petr.petorv@mail.ru', '(786)0961231');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (3, 'Petrov', 'Petr', 'Petrovich', '1997.01.02', 'petr.petorv@mail.ru', '(786)9924231');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (1, 'Tarov', 'Boris', 'Arkadievich', '1978.05.07', 'boris.tarov@dental.com', '(964)9876546');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (2, 'Sergeeva', 'Anna', 'Petrovna', '2000', 'anna.sergeeva@dental.com', '(342)8097032');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (2, 'Garin', 'Aleksej', 'Sidorovich', '1964.01.20', 'aleksej.garin@dental.com', '(878)0834768');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (4, 'Kogan', 'Alena', 'Viktorovna', '1954.11.21', 'alena.kogan@dental.com', '(856)0839388');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (6, 'Dimov', 'Viktor', 'Tarasovich', '1998.06.10', 'viktor.dimov@dental.com', '(458)9784768');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (5, 'Dodon', 'Roman', 'Ivanovich', '2001.01.18', 'roman.dodon@dental.com', '(478)0827618');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (8, 'Parshina', 'Elena', 'Sidorovna', '1949.05.14', 'elena.parshina@dental.com', '(321)0894236');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (7, 'Garina', 'Maria', 'Sidorovna', '1966.09.12', 'maria.garina@dental.com', '(878)0834758');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (10, 'Borodina', 'Anastasiya', 'Yurivna', '1999.08.08', 'anastasiya.borodina@dental.com', '(067)9034768');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (9, 'Duka', 'Nadezhda', 'Andreevna', '2002.01.24', 'nadezhda.duka@dental.com', '(099)0834362');
INSERT INTO Employees (ocupation_id, surname, name, patronimic, dob, email, phone) VALUES (1, 'Skorobogatov', 'Anatolija', 'Spiridonovich', '1977.09.03', 'anatolij.skorobogatov@dental.com', '(099)4834768');
GO

INSERT INTO DentalServices (ocupation_id, description, price) VALUES(2, 'Filling', '20.00');                   ---1
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(2, 'Rroot canals', '15.00');              ---2
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(1, 'Extractions', '25.00');               ---3
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(6, 'Complete exams', '10.00');            ---4
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(5, 'X-ray', '10.00');                     ---5
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(4, 'Dental Check Up', '15.00');           ---6
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(4, 'Decay removal', '5.00');              ---7
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(10, 'Fixed bridge', '25.00');             ---8
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(10, 'Implant-supported bridge', '30.00'); ---9
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(4, 'Professional Cleaning', '20.00');     ---10
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(10, 'Scaling and Root Planing', '10.00'); ---11
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(4, 'Tooth Whitening', '15.00');           ---12
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(10, 'Veneers', '25.00');                  ---13
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(10, 'Braces', '25.00');                   ---14
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(1, 'Wisdom teeth removal', '30.00');      ---15
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(10, 'Crowns', '35.00');                   ---16
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(4, 'Enamel Shaping', '15.00');            ---17
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(2, 'Tooth Filling', '20.00');             ---18
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(1, 'Extraction of teeth', '35.00');       ---19
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(2, 'Root canal therapy', '25.00');        ---20
INSERT INTO DentalServices (ocupation_id, description, price) VALUES(3, 'Extra Care', '10.00');                ---21
GO

INSERT INTO Orders (patient_id, paycard_id, paystatus) VALUES (5, 2, 0);
INSERT INTO Orders (patient_id, paycard_id) VALUES (11, 1);
INSERT INTO Orders (patient_id, paycard_id) VALUES (3, 7);
INSERT INTO Orders (patient_id, paycard_id, paystatus) VALUES (7, 3, 1);
INSERT INTO Orders (patient_id, paycard_id, paystatus) VALUES (5, 2, 1);
INSERT INTO Orders (patient_id, paycard_id) VALUES (5, 6);
INSERT INTO Orders (patient_id, paycard_id, paystatus) VALUES (2, 5, 1);
INSERT INTO Orders (patient_id, paycard_id, paystatus) VALUES (2, 4, 1);
INSERT INTO Orders (patient_id, paycard_id, paystatus) VALUES (4, 6, 9);
GO

INSERT INTO OrderLines (order_id, service_id) VALUES (1, 21)
INSERT INTO OrderLines (order_id, service_id) VALUES (1, 3);
INSERT INTO OrderLines (order_id, service_id) VALUES (1, 5);
INSERT INTO OrderLines (order_id, service_id) VALUES (1, 7);
INSERT INTO OrderLines (order_id, service_id) VALUES (2, 3);
INSERT INTO OrderLines (order_id, service_id) VALUES (2, 2);
INSERT INTO OrderLines (order_id, service_id) VALUES (3, 5);
INSERT INTO OrderLines (order_id, service_id) VALUES (4, 8);
INSERT INTO OrderLines (order_id, service_id) VALUES (6, 9);
INSERT INTO OrderLines (order_id, service_id) VALUES (8, 4);
INSERT INTO OrderLines (order_id, service_id) VALUES (1, 9);
GO
----------------------END OF DATA--------------------

