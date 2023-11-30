  --Procedure 1: Retrieve Patient Information by Room ID
--Input Parameters: Room ID
--Output: Patient information for the specified Room ID

  CREATE PROCEDURE GetPatientsByRoomID
    @InputRoomID INT
AS
BEGIN
    SELECT P.Patient_ID, P.Patient_Name, P.Patient_Address_Encrypted, P.Patient_Phonenumber_Encrypted, W.Ward_Type
    FROM Patient AS P
    INNER JOIN Ward AS W ON P.Room_ID = W.Room_ID
    WHERE P.Room_ID = @InputRoomID;
END;

--Output
EXEC GetPatientsByRoomID @InputRoomID = 201;

drop procedure GetPatientsByRoomID


--Procedure 2: Calculate Total Salary Expense
--Output: Total salary expense for a specific department

CREATE PROCEDURE CalculateTotalSalaryExpense
    @InputDepartmentID INT,
    @OutputTotalSalary DECIMAL(10, 2) OUTPUT
AS
BEGIN
    SELECT @OutputTotalSalary = SUM(P.Net_Salary)
    FROM Payroll AS P
    INNER JOIN Employee AS E ON P.Employee_ID = E.Employee_ID
    WHERE E.Department_ID = @InputDepartmentID;

    IF @OutputTotalSalary IS NULL
        SET @OutputTotalSalary = 0;
END;

--Output
DECLARE @TotalSalary DECIMAL(10, 2);
EXEC CalculateTotalSalaryExpense @InputDepartmentID = 1, @OutputTotalSalary = @TotalSalary OUTPUT;
PRINT 'Total Salary Expense: ' + CONVERT(VARCHAR, @TotalSalary);


--Procedure 3: Get Doctor Appointments
--Input Parameters: Doctor Employee ID, Start Date, End Date
--Output: Appointments for the specified doctor within the date range

CREATE PROCEDURE GetDoctorAppointments
    @InputDoctorEmployeeID INT,
    @InputStartDate DATE,
    @InputEndDate DATE
AS
BEGIN
    SELECT A.Appointment_ID, A.Patient_ID, P.Patient_Name, A.Start_Date_Time, A.End_Date_Time
    FROM Appointment AS A
    INNER JOIN Patient AS P ON A.Patient_ID = P.Patient_ID
    WHERE A.D_Employee_ID = @InputDoctorEmployeeID
      AND A.Start_Date_Time BETWEEN @InputStartDate AND @InputEndDate;
END;

--Output
EXEC GetDoctorAppointments @InputDoctorEmployeeID = 21, @InputStartDate = '2023-01-01', @InputEndDate = '2023-12-31';


--Procedure 4 : GetAvailableBedsByWardType:
--This procedure returns the count of available beds for a specific ward type.

CREATE PROCEDURE GetAvailableBedsByWardType
    @WardType VARCHAR(255)
AS
BEGIN
    SELECT Ward_Type, COUNT(*) AS AvailableBeds
    FROM Ward
    WHERE Ward_Type = @WardType
    GROUP BY Ward_Type;
END;

--Output:
EXEC GetAvailableBedsByWardType 'General';


--View 1: PatientDetailsView
--This view provides information about patients along with their assigned rooms and diseases.

CREATE VIEW PatientDetailsView AS
SELECT
    P.Patient_ID,
    P.Patient_Name,
    P.Patient_Address_Encrypted,
    P.Patient_Phonenumber_Encrypted,
    W.Room_ID,
    W.Bed_Number,
    W.Ward_Type,
    W.Floor_Number,
    DH.Disease_Name
FROM
    Patient P
JOIN Ward W ON P.Room_ID = W.Room_ID
LEFT JOIN PatientDiseaseHistory PDH ON P.Patient_ID = PDH.Patient_ID
LEFT JOIN Disease DH ON PDH.Disease_ID = DH.Disease_ID;

drop view WardOccupancyView

--Output
SELECT * FROM PatientDetailsView;


--View 2: WardOccupancyView
--This view provides information about the occupancy status of each ward.

CREATE VIEW WardOccupancyView AS
SELECT
    W.Room_ID,
    W.Bed_Number,
    W.Ward_Type,
    W.Floor_Number,
    P.Patient_Name,
    P.Patient_Address_Encrypted,
    P.Patient_Phonenumber_Encrypted
FROM
    Ward W
LEFT JOIN Patient P ON W.Room_ID = P.Room_ID;

--Output
SELECT * FROM WardOccupancyView;


--View 3: NurseAssignmentView
--This view provides information about nurse assignments and their respective wards.

CREATE VIEW NurseAssignmentView AS
SELECT
    NW.Assignment_ID,
    N.Nurse_Floor,
    E.Employee_FirstName + ' ' + E.Employee_LastName AS Nurse_Name,
    W.Room_ID,
    W.Ward_Type,
    W.Floor_Number,
    NW.Assignment_Date
FROM
    NurseWardAssignment NW
JOIN Nurse N ON NW.N_Employee_ID = N.N_Employee_ID
JOIN Employee E ON NW.N_Employee_ID = E.Employee_ID
JOIN Ward W ON NW.Room_ID = W.Room_ID;

--Output
SELECT * FROM NurseAssignmentView;



-- Create a DML trigger for notifying when a patient is admitted or discharged
CREATE TRIGGER PatientAdmissionDischargeTrigger
ON PatientDiseaseHistory
AFTER INSERT, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        -- Patient Admission Notification
        PRINT 'Patient Admitted. Notify ENT department.';
    END
    ELSE IF EXISTS (SELECT * FROM deleted)
    BEGIN
        -- Patient Discharge Notification
        PRINT 'Patient Discharged. Perform discharge procedures.';
    END
END;


--Test Case
INSERT INTO PatientDiseaseHistory (Patient_ID, Disease_ID, Admission_Reason, Admission_Date, Primary_Doctor_Name)
VALUES (109, 11, 'Test Admission', '2023-12-01', 'Test Doctor');

SELECT * FROM PatientDiseaseHistory;



-- 1. Check constraint for ensuring valid Net_Salary values in Payroll table
ALTER TABLE Payroll
ADD CONSTRAINT CHK_ValidNetSalary CHECK (Net_Salary >= 0);

-- 2. Check constraint for ensuring positive Quantity in Dispensary table
ALTER TABLE Dispensary
ADD CONSTRAINT CHK_PositiveQuantity CHECK (Quantity > 0);

-- 3. Check constraint for ensuring valid Nurse_Floor values in Nurse table
ALTER TABLE Nurse
ADD CONSTRAINT CHK_ValidNurseFloor CHECK (Nurse_Floor > 0 AND Nurse_Floor < 6);



--the UDF-1 IsValidPhoneNumberFormat takes the Employee_PhoneNumber as a parameter and returns a bit (1 or 0) indicating whether the phone number is in a valid format. 
--The computed column IsValidPhoneFormat is added to the Employee table, and its value is calculated based on the UDF.
CREATE FUNCTION dbo.IsValidPhoneNumberFormat(@PhoneNumber VARCHAR(15))
RETURNS BIT
AS
BEGIN
    DECLARE @ValidFormat BIT = 0;

    IF @PhoneNumber LIKE '___-___-____'
        SET @ValidFormat = 1;

    RETURN @ValidFormat;
END;

-- Step 2: Add a computed column to the Employee table
ALTER TABLE Employee
ADD IsValidPhoneFormat AS dbo.IsValidPhoneNumberFormat(Employee_PhoneNumber);

-- Select data from the Employee table to see the computed column
SELECT Employee_ID, Department_ID, Employee_FirstName, Employee_LastName, Employee_PhoneNumber, IsValidPhoneFormat
FROM Employee;


--the UDF-2 CalculateHospitalStayDuration takes the Admission_Date and Discharge_Date as parameters and returns the duration of the hospital stay in days.
--The computed column HospitalStayDuration is added to the PatientDiseaseHistory table, and its value is calculated based on the UDF.
CREATE FUNCTION dbo.CalculateHospitalStayDuration(@AdmissionDate DATE, @DischargeDate DATE)
RETURNS INT
AS
BEGIN
    DECLARE @StayDuration INT;

    SET @StayDuration = DATEDIFF(DAY, @AdmissionDate, @DischargeDate);

    RETURN @StayDuration;
END;

-- Step 2: Add a computed column to the PatientDiseaseHistory table
ALTER TABLE PatientDiseaseHistory
ADD HospitalStayDuration AS dbo.CalculateHospitalStayDuration(Admission_Date, Discharge_Date);

-- Select data from the PatientDiseaseHistory table to see the computed column
SELECT Patient_Record_Number, Patient_ID, Disease_ID, Admission_Reason, Admission_Date, Primary_Doctor_Name, Discharge_Date, HospitalStayDuration
FROM PatientDiseaseHistory;

--Non-Clustered Index
CREATE NONCLUSTERED INDEX IX_Patient_Patient_ID ON Patient(Patient_ID);

CREATE NONCLUSTERED INDEX IX_Employee_Department_ID ON Employee(Department_ID);

CREATE NONCLUSTERED INDEX IX_PatientDiseaseHistory_Disease_ID ON PatientDiseaseHistory(Disease_ID);

CREATE NONCLUSTERED INDEX IX_Appointment_D_Employee_ID ON Appointment (D_Employee_ID);


--Column Data Encryption (encrypting and decrypting the Patient_Address column in the Patient table)

-- Create a symmetric key
CREATE SYMMETRIC KEY SymmetricKey_HMS
WITH ALGORITHM = AES_256
ENCRYPTION BY PASSWORD = 'HMS';


-- Alter the Patient table to encrypt columns
ALTER TABLE Patient
ADD Patient_Address_Encrypted VARBINARY(MAX) NULL;

ALTER TABLE Patient
ADD Patient_Phonenumber_Encrypted VARBINARY(MAX) NULL;

alter table patient
drop column Patient_Phonenumber_Encrypted

-- Update existing data with encrypted values
OPEN SYMMETRIC KEY SymmetricKey_HMS
DECRYPTION BY PASSWORD = 'HMS';

UPDATE Patient
SET Patient_Address_Encrypted = ENCRYPTBYKEY(KEY_GUID('SymmetricKey_HMS'), CONVERT(VARBINARY(MAX), Patient_Address));

UPDATE Patient
SET Patient_Phonenumber_Encrypted = ENCRYPTBYKEY(KEY_GUID('SymmetricKey_HMS'), CONVERT(VARBINARY(MAX), Patient_Phonenumber));

-- Drop the original unencrypted columns if you want
ALTER TABLE Patient
DROP COLUMN Patient_Address;

ALTER TABLE Patient
DROP COLUMN Patient_Phonenumber;

select * from patient

--Decryption
-- Open the symmetric key for decryption
OPEN SYMMETRIC KEY SymmetricKey_HMS
DECRYPTION BY PASSWORD = 'HMS';

-- Select and decrypt data
SELECT 
    Patient_ID,
    Patient_Name,
    CONVERT(VARCHAR(255), DECRYPTBYKEY(Patient_Address_Encrypted)) AS Patient_Address
FROM Patient;

SELECT 
    Patient_ID,
    Patient_Name,
    CONVERT(INTEGER, DECRYPTBYKEY(Patient_Phonenumber_Encrypted)) AS Patient_Phonenumber
FROM Patient;

