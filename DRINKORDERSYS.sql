CREATE DATABASE DRINKORDERSYSTEM

CREATE TABLE ItemMenu
(
	I_ID varchar(10) primary key,
	I_Name NVARCHAR(100) NOT NULL,
	I_Category NVARCHAR(50) NOT NULL,
	I_Price DECIMAL(12,3) NOT NULL,
	I_Status NVARCHAR(20) NOT NULL DEFAULT 'Not Available'
	-- Dùng để ràng buộc ItemStatus
	CONSTRAINT CHK_ItemStatus CHECK (I_Status IN ('Not Available', 'Available'))
)

CREATE TABLE Customer
(
	C_ID varchar(10) primary key NOT NULL,
	C_Name nvarchar(100) not null,
	C_Address nvarchar (100) not null,
	C_PhoneNumber INT NOT NULL,
)

CREATE TABLE Orders 
(
	O_ID varchar(10) primary key NOT NULL,
	O_Price DECIMAL(12,3) NOT NULL,
	O_Date DATETIME DEFAULT CURRENT_TIMESTAMP,
)

CREATE TABLE MakeOrder (
	I_ID varchar(10) not null,
	O_ID varchar(10) not null,	
	FOREIGN KEY (O_ID) REFERENCES Orders(O_ID),
    FOREIGN KEY (I_ID) REFERENCES ItemMenu(I_ID),
)

CREATE TABLE CreateOrder
(
	I_ID varchar (10) not null,
	C_ID varchar (10) not null,
	FOREIGN KEY (I_ID) REFERENCES ItemMenu(I_ID),
    FOREIGN KEY (C_ID) REFERENCES Customer(C_ID),
)

CREATE TABLE OrderDetails (
	O_ID varchar (10) not null,
	C_ID varchar (10) not null,
	Note nvarchar (100) not null,
	Status NVARCHAR(20) NOT NULL DEFAULT 'Pending',
	Quantity INT NOT NULL,
	FOREIGN KEY (O_ID) REFERENCES Orders(O_ID),
    FOREIGN KEY (C_ID) REFERENCES ItemMenu(I_ID),
	CONSTRAINT CHK_OrderStatus CHECK (Status IN ('Pending', 'Confirmed', 'Preparing', 'Ready', 'Delivered', 'Cancelled'))	
)

CREATE TABLE Cooker
(
	CO_ID INT PRIMARY KEY NOT NULL,	
	CO_address NVARCHAR(MAX) NOT NULL,
	-- Decimal(p, s): 
	-- p: tổng chữ số; 
	-- s: số chữ số sau thập phân;
	CO_Salary DECIMAL(12,3) NOT NULL, CHECK (CO_salary >= 0),
	CO_DOB DATE NOT NULL,	
	CO_Name NVARCHAR (MAX) NOT NULL,
	ManagerID INT NULL, -- Cho phép null ở cấp cao Nhất	
	FOREIGN KEY (ManagerID) REFERENCES Cooker(CO_ID)
)

Create Table Manager
(
	CO_ID INT NOT NULL, -- ID của cooker
    ManagerID INT NOT NULL, -- ID của người quản lý
    CO_ID_Absent INT, -- ID của cooker vắng mặt (có thể null)
    Manager_Date DATE, -- Ngày quản lý liên quan
    CO_left INT, -- Sĩ số cooker
    PRIMARY KEY (CO_ID, ManagerID), -- Khóa chính là cặp (C_ID, ManagerID)
    FOREIGN KEY (CO_ID) REFERENCES Cooker(CO_ID),
    FOREIGN KEY (ManagerID) REFERENCES Cooker(CO_ID),
    FOREIGN KEY (CO_ID_Absent) REFERENCES Cooker(CO_ID) -- Nếu C_ID_Absent là tham chiếu đến cooker khác
)

CREATE TABLE Ingredient
(
	IN_id INT PRIMARY KEY NOT NULL,
	IN_UnitPrice DECIMAL (12,3) NOT NULL CHECK (IN_UnitPrice >= 0),
	IN_amount INT NOT NULL CHECK (IN_amount >= 0),
	IN_Name NVARCHAR(50) NOT NULL,
	IN_UnitType NVARCHAR(MAX) NOT NULL,
	-- Insert dispose_id into Ingredient column		
	-- To identify which process owns the ingredient    		
    IN_ConversionFactor DECIMAL(18,6) NOT NULL DEFAULT 1,
)

-- Ví dụ : Với nước, gán IN_ConversionFactor 

UPDATE Ingredient
SET IN_ConversionFactor = 1000000
WHERE IN_Name = N'nước';

CREATE TABLE Supplier
(
	S_ID INT PRIMARY KEY NOT NULL,
	S_Address NVARCHAR(MAX) NOT NULL,
	S_Phonenumber NVARCHAR(15) NOT NULL CHECK (S_PhoneNumber >= 0),
	S_Name NVARCHAR(MAX) NOT NULL,
)

CREATE TABLE Transaction_I
(
    O_ID VARCHAR(10) NOT NULL,
    IN_id INT NOT NULL,
    C_ID varchar(10) NOT NULL,
    CO_ID INT NOT NULL,
    change DECIMAL(12,3),
    type NVARCHAR(50) NOT NULL CHECK (type IN (N'chuyển khoản', N'thanh toán trực tiếp')),
	result NVARCHAR(MAX) NOT NULL CHECK (result IN ('ReadyToCook', 'InsufficientIngredients', 'PaymentIssue')),    
    receiveByID INT NULL,
    Cus_Pay DECIMAL(12,3) NOT NULL CHECK (Cus_Pay >= 0),
    PRIMARY KEY (O_ID, IN_id), -- Khóa chính để đảm bảo mối quan hệ N:N giữa Orders và Ingredient
    FOREIGN KEY (O_ID) REFERENCES Orders(O_ID),
    FOREIGN KEY (IN_id) REFERENCES Ingredient(IN_id),
    FOREIGN KEY (C_ID) REFERENCES Customer(C_ID),
    FOREIGN KEY (CO_ID) REFERENCES Cooker(CO_ID),
    CONSTRAINT CHK_ReceiveByID CHECK (
        (type = N'chuyển khoản' AND receiveByID IS NULL) OR
        (type = N'thanh toán trực tiếp' AND receiveByID IS NOT NULL)
    )
);

CREATE TABLE Transaction_II
(
    TransactionID INT PRIMARY KEY IDENTITY(1,1),  -- Thêm mã giao dịch duy nhất
    IN_id INT NOT NULL,
    S_ID INT NOT NULL,
    Note NVARCHAR(255),  -- Giảm kích thước nếu phù hợp
    ImportCost DECIMAL(12,3) NOT NULL CHECK (ImportCost >= 0),
    Result NVARCHAR(20) NOT NULL CHECK (Result IN ('DeliveryFailed', 'DeliverySucceed', 'Pending')),
    ImportDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    TransactionAmount DECIMAL(12,3) NOT NULL CHECK (TransactionAmount >= 0),  -- Đổi sang DECIMAL
    ImportWater DECIMAL(12,3) NULL,  -- Cho phép NULL nếu không liên quan đến nước
    WaterUnitPrice DECIMAL(12,3) NULL,  -- Cho phép NULL
    VAT DECIMAL(5,2) DEFAULT 5,
    EnvironmentalFee DECIMAL(5,2) DEFAULT 10,
    TotalCost AS (ImportCost + COALESCE(ImportWater * WaterUnitPrice * (1 + VAT / 100 + EnvironmentalFee / 100), 0)),  -- Cột tính toán
    FOREIGN KEY (IN_id) REFERENCES Ingredient(IN_id),
    FOREIGN KEY (S_ID) REFERENCES Supplier(S_ID)
);

CREATE TABLE ItemConcept
(
	I_ID varchar(10) NOT NULL,
	concept NVARCHAR(MAX) NOT NULL,
	PRIMARY KEY (I_ID),
	FOREIGN KEY (I_ID) REFERENCES ItemMenu(I_ID)
);

-- ===============================================================================================================
-- THỦ TỤC LÀM VIỆC 

go
CREATE PROCEDURE UpdateTransactionResult
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE t
    SET t.result = 
        CASE 
            -- Kiểm tra tài chính và nguyên liệu
            WHEN (t.Cus_Pay >= o.O_Price AND t.change >= 0 AND 
                  (SELECT COUNT(*) 
                   FROM OrderDetails od
                   JOIN ItemConcept ic ON od.C_ID = ic.I_ID
                   CROSS APPLY STRING_SPLIT(ic.Concept, ',') AS sp
                   CROSS APPLY (SELECT TRIM(value) AS item, 
                                       CAST(PARSENAME(REPLACE(TRIM(value), N' ', '.'), 2) AS INT) AS qty,
                                       PARSENAME(REPLACE(TRIM(value), N' ', '.'), 1) AS unit_name
                                ) AS parsed
                   JOIN Ingredient i ON i.IN_Name = parsed.unit_name
                   WHERE od.O_ID = t.O_ID
                   GROUP BY od.O_ID
                   HAVING SUM(parsed.qty * od.Quantity) <= MIN(i.IN_amount)) = 1) 
                THEN 'ReadyToCook'
            -- Kiểm tra thiếu nguyên liệu
            WHEN (SELECT COUNT(*) 
                  FROM OrderDetails od
                  JOIN ItemConcept ic ON od.C_ID = ic.I_ID
                  CROSS APPLY STRING_SPLIT(ic.Concept, ',') AS sp
                  CROSS APPLY (SELECT TRIM(value) AS item, 
                                      CAST(PARSENAME(REPLACE(TRIM(value), N' ', '.'), 2) AS INT) AS qty,
                                      PARSENAME(REPLACE(TRIM(value), N' ', '.'), 1) AS unit_name
                               ) AS parsed
                  JOIN Ingredient i ON i.IN_Name = parsed.unit_name
                  WHERE od.O_ID = t.O_ID
                  GROUP BY od.O_ID
                  HAVING SUM(parsed.qty * od.Quantity) > MIN(i.IN_amount)) = 1 
                THEN 'InsufficientIngredients'
            -- Kiểm tra vấn đề thanh toán
            ELSE 'PaymentIssue'
        END
    FROM Transaction_I t
    JOIN Orders o ON t.O_ID = o.O_ID
    JOIN OrderDetails od ON t.O_ID = od.O_ID;

END;
GO

-- 

