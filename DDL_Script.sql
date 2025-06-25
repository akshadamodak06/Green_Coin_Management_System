DROP SCHEMA IF EXISTS GREENCOIN CASCADE;
CREATE SCHEMA GREENCOIN;

SET SEARCH_PATH TO GREENCOIN;

CREATE TABLE Regulator (
    RegulatorID CHAR(6) PRIMARY KEY,
    RegulatorName VARCHAR(255) NOT NULL,
    PhoneNumber CHAR(10) NOT NULL UNIQUE,
    RegEmail VARCHAR(255) NOT NULL UNIQUE,
    Jurisdiction VARCHAR(255) NOT NULL,
    "State" VARCHAR(100) NOT NULL,
    Government VARCHAR(255) NOT NULL,
	CONSTRAINT chk_RegPhone CHECK (PhoneNumber ~ '^[0-9]{10}$')
);

CREATE TABLE GovernmentPolicy (
    PolicyID CHAR(6) PRIMARY KEY,
    PolicyName VARCHAR(255) NOT NULL,
    PolicyDescription TEXT NOT NULL,
    EffectiveDate DATE NOT NULL,
    LastUpdateDate DATE NOT NULL,
    GoverningBody VARCHAR(255)NOT NULL
);

CREATE TABLE Regulation (
    RegulatorID CHAR(6),
    PolicyID CHAR(6) UNIQUE,
	  PRIMARY KEY(RegulatorID,PolicyID),
    FOREIGN KEY (PolicyID) REFERENCES GovernmentPolicy(PolicyID)
		ON DELETE CASCADE ON UPDATE CASCADE,
	  FOREIGN KEY (RegulatorID) REFERENCES Regulator(RegulatorID)
		ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Reward (
    RewardID CHAR(6) PRIMARY KEY,
    RewardType VARCHAR(255) NOT NULL,
    RewardDescription TEXT NOT NULL,
    RewardIssueDate DATE NOT NULL,
    RegulatorID CHAR(6) NOT NULL,
    FOREIGN KEY (RegulatorID) REFERENCES Regulator(RegulatorID)
		ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE Company (
    RegNo NUMERIC(10,0) PRIMARY KEY,
    IndustryType VARCHAR(255) NOT NULL,
    ChiefOfficer VARCHAR(255) NOT NULL,
    ContactNo CHAR(10) NOT NULL UNIQUE,
    CompanyName VARCHAR(255) NOT NULL UNIQUE,
	  "Address" TEXT NOT NULL,
    EstYear INT NOT NULL,
    CType VARCHAR(255) NOT NULL
	CONSTRAINT chk_CompanyContact CHECK (ContactNo ~ '^[0-9]{10}$'),
	CONSTRAINT chk_CompanyEstYear CHECK (EstYear < EXTRACT(YEAR FROM CURRENT_DATE))
);

CREATE TABLE CompanyEmail (
    CEmail VARCHAR(255),
    RegNo NUMERIC(10,0),
	PRIMARY KEY (CEmail, RegNo),
    FOREIGN KEY (RegNo) REFERENCES Company(RegNo)
		ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE Credit (
    CreditAllocatedYear INT,
    RegNo NUMERIC(10,0),
    CProduced DECIMAL(10,2) NOT NULL,
    CAllocated DECIMAL(10,2) NOT NULL,
    CSell DECIMAL(10,2),
    CBuy DECIMAL(10,2),
	CNgo DECIMAL(10,2),
    RegulatorID CHAR(6) NOT NULL,
    PRIMARY KEY (CreditAllocatedYear, RegNo),
    FOREIGN KEY (RegNo) REFERENCES Company(RegNo)
		ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (RegulatorID) REFERENCES Regulator(RegulatorID)
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT chk_CreditPositive CHECK (
    CProduced >= 0 AND CAllocated >= 0 AND (CSell IS NULL OR CSell >= 0) AND (CBuy IS NULL OR CBuy >= 0) AND (CNgo IS NULL OR CNgo >= 0))
);
CREATE TABLE Penalty (
    PenaltyID CHAR(6) PRIMARY KEY,
    StartDate DATE NOT NULL,
    PayDate DATE,
    Amount DECIMAL(12,2) NOT NULL,
	  RegNo NUMERIC(10,0) NOT NULL,
    CreditAllocatedYear INT NOT NULL,
    RegulatorID CHAR(6),
    FOREIGN KEY (RegulatorID) REFERENCES Regulator(RegulatorID)
		ON DELETE CASCADE ON UPDATE CASCADE,
	  FOREIGN KEY (CreditAllocatedYear, RegNo) REFERENCES Credit(CreditAllocatedYear, RegNo)
		ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE POCs (
    POCID CHAR(6) PRIMARY KEY,
    FullName VARCHAR(255) NOT NULL,
    ContactNo CHAR(10) NOT NULL UNIQUE,
    DOB DATE NOT NULL,
    Gender CHAR(1) NOT NULL,
	TenureStartDate DATE NOT NULL,
	TenureEndDate DATE,
	CONSTRAINT chk_POCContact CHECK (ContactNo ~ '^[0-9]{10}$'),
	CONSTRAINT chk_Gender CHECK (Gender IN ('M', 'F', 'O')),
	CONSTRAINT chk_POCDates CHECK (TenureEndDate IS NULL OR TenureStartDate < TenureEndDate)
);
CREATE TABLE Branch (
    RegNo NUMERIC(10,0),
    "State" VARCHAR(50),
    City VARCHAR(50),
    BranchCredits DECIMAL(10,2),
    POCID CHAR(6) NOT NULL,
	"Year" INT,
	Size DECIMAL(10,2),
	StartDate DATE,
    PRIMARY KEY (RegNo, "State", City,"Year"),
    FOREIGN KEY (RegNo) REFERENCES Company(RegNo)
		ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (POCID) REFERENCES POCs(POCID)
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT chk_BranchCredits CHECK (BranchCredits >= 0)
);

CREATE TABLE Project (
    ProjectID CHAR(6) PRIMARY KEY,
    ProjectName VARCHAR(255) NOT NULL,
    ProjectType VARCHAR(255) NOT NULL,
    ProjectDescription TEXT,
	  "Status" VARCHAR(100),
    StartDate DATE NOT NULL,
    EndDate DATE,
    RegNo NUMERIC(10,0) NOT NULL,
    "State" VARCHAR(50) NOT NULL,
    City VARCHAR(50) NOT NULL,
	"Year" INT NOT NULL,
	 FOREIGN KEY (RegNo, "State", City, "Year") REFERENCES Branch(RegNo, "State", City, "Year")
		ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT chk_ProjectDates CHECK (EndDate IS NULL OR StartDate < EndDate),
	CONSTRAINT chk_ProjectStatus CHECK ("Status" IN ('Active', 'Completed', 'On Hold', 'Cancelled') OR "Status" IS NULL)
);


CREATE TABLE "Transaction" (
    TransactionID VARCHAR(20) PRIMARY KEY,
    SellerRegNo NUMERIC(10,0) NOT NULL,
    BuyerRegNo NUMERIC(10,0) NOT NULL,
    TDate DATE NOT NULL,
    CreditsTraded DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (SellerRegNo) REFERENCES Company(RegNo)
		ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (BuyerRegNo) REFERENCES Company(RegNo)
		ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE POCEmail (
    POCEmail VARCHAR(255),
    POCID CHAR(6),
	  PRIMARY KEY (POCID,POCEmail),
    FOREIGN KEY (POCID) REFERENCES POCs(POCID)
		ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE GreenhouseGases (
    GasName VARCHAR(255) PRIMARY KEY,
    CO2e DECIMAL(10,2) NOT NULL,
    ChemicalFormula VARCHAR(50) NOT NULL UNIQUE
);
CREATE TABLE CompanyType (
    CompanyType VARCHAR(255) PRIMARY KEY,
    IndustryType  VARCHAR(255)
);
CREATE TABLE CompanyTypeGasMapping (
    GasName VARCHAR(255),
    CompanyType VARCHAR(255),
    PRIMARY KEY (GasName, CompanyType),
    FOREIGN KEY (GasName) REFERENCES GreenhouseGases(GasName)
		ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (CompanyType) REFERENCES CompanyType(CompanyType)
		ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE CompanyEmission (
    EmissionYear INT,
    RegNo NUMERIC(10,0),
    GasName VARCHAR(255),
    CompanyType VARCHAR(255),
    EquivalentTonnes DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (EmissionYear, RegNo, GasName,CompanyType),
    FOREIGN KEY (RegNo) REFERENCES Company(RegNo)ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (GasName,CompanyType) REFERENCES CompanyTypeGasMapping(GasName,CompanyType)ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Conditions (
    ConditionID CHAR(6) PRIMARY KEY,
    ConditionName VARCHAR(255) NOT NULL,
    ConditionDescription TEXT NOT NULL,
    Unit VARCHAR(255),
    ThresholdValue DECIMAL(10,2),
    VerificationMethod TEXT,
    RewardID CHAR(6) NOT NULL,
    FOREIGN KEY (RewardID) REFERENCES Reward(RewardID)
		ON DELETE CASCADE ON UPDATE CASCADE   
);

CREATE TABLE CompanyConditions (
    RegNo NUMERIC(10,0),
    ConditionID CHAR(6),
    "Year" INT,
    PRIMARY KEY (RegNo, ConditionID, "Year"),
    FOREIGN KEY (RegNo) REFERENCES Company(RegNo)
		ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ConditionID) REFERENCES Conditions(ConditionID)
		ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE NGOs(
    NGORegNo CHAR(6),
    NGOProjectID CHAR(6),
    ProjectTitle VARCHAR(255) NOT NULL,
    CreditReduced DECIMAL(10,2) NOT NULL,
    StartYear INT NOT NULL,
    EndYear INT,
	PRIMARY KEY (NGORegNo, NGOProjectID),
	CONSTRAINT chk_NGOYears CHECK (EndYear IS NULL OR StartYear < EndYear)
);

CREATE TABLE NGOCollabrations (
    CreditAllocatedYear INT,
    RegNo NUMERIC(10,0),
    NGORegNo CHAR(6) ,
    NGOProjectID CHAR(6),
    PRIMARY KEY (CreditAllocatedYear, RegNo, NGORegNo, NGOProjectID),
    FOREIGN KEY (RegNo, CreditAllocatedYear) REFERENCES Credit(RegNo, CreditAllocatedYear)
		ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (NGORegNo, NGOProjectID) REFERENCES NGOs(NGORegNo, NGOProjectID)
		ON DELETE CASCADE ON UPDATE CASCADE
); 




