-- Pub(PLN, PubName, PCounty)
-- NeighbourCounty(County1, County2)
-- Person(PPSN, PName, PCounty, Age, DailyPubLimit)
-- Visit(PLN, PPSN, StartDateOfVisit, EndDateOfVisit)
-- Covid_Diagnosis(PPSN, DiagnosisDate, IsolationEndDate)

DROP TABLE IF EXISTS Pub;
CREATE TABLE Pub (
    PLN varchar(255),
    PubName varchar(255),
    PCounty varchar(255),
    PRIMARY KEY(PLN)
    
);

DROP TABLE IF EXISTS NeighbourCounty;
CREATE TABLE NeighbourCounty (
    County1 varchar(255),
    County2 varchar(255)
    
);


DROP TABLE IF EXISTS Person;
CREATE TABLE Person (
    PPSN int,
    PName varchar(255),
    PCounty varchar(255),
    Age int,
    DailyPubLimit int,
    PRIMARY KEY(PPSN)
);

DROP TABLE IF EXISTS Visit;	#fix fk cannot add foreign key constraint
CREATE TABLE Visit (
    PLN varchar(255),
    PPSN int,
    StartDateOfVisit DATETIME,
    EndDateOfVisit DATETIME,
    FOREIGN KEY (PLN) REFERENCES Pub(PLN),
    FOREIGN KEY (PPSN) REFERENCES Person(PPSN),
   	PRIMARY KEY(StartDateOfVisit, EndDateOfVisit, PPSN, PLN)
    
);

-- Covid_Diagnosis(PPSN, DiagnosisDate, IsolationEndDate)

DROP TABLE IF EXISTS Covid_Diagnosis;
CREATE TABLE Covid_Diagnosis (
    PPSN int,
    DiagnosisDate date,
    IsolationEndDate date,
    FOREIGN KEY (PPSN) REFERENCES Person(PPSN),
	PRIMARY KEY (PPSN)
);

INSERT INTO Pub
VALUES ('L1234', 'Murphy’s', 'Cork');

INSERT INTO Pub
VALUES ('L2345', 'Joe’s', 'Limerick');

INSERT INTO Pub
VALUES ('L3456', 'BatBar', 'Kerry');

-- SELECT * from Pub

INSERT INTO NeighbourCounty
VALUES ('Cork', 'Limerick');

INSERT INTO NeighbourCounty
VALUES ('Limerick', 'Cork');

INSERT INTO NeighbourCounty
VALUES ('Cork', 'Kerry');

INSERT INTO NeighbourCounty
VALUES ('Kerry', 'Cork');

-- SELECT * from NeighbourCounty nc 

INSERT INTO Person
VALUES (1, 'Liza', 'Cork', 22, 5);

INSERT INTO Person
VALUES (2, 'Alex', 'Limerick', 19, 7);

INSERT INTO Person
VALUES (3, 'Tom', 'Kery', 23, 10);

INSERT INTO Person
VALUES (4, 'Peter', 'Cork', 39, 8);

-- SELECT * from Person p 

INSERT INTO Visit 
values('L1234', 1, '2020-02-10 10:00:00', '2020-02-10 11:00:00');

INSERT INTO Visit 
values('L1234', 1, '2020-12-08 11:00:00', '2020-12-08 11:35:00');

INSERT INTO Visit 
values('L1234', 3, '2020-12-03 11:00:00', '2020-12-03 11:50:00');


-- SELECT * FROM Visit

INSERT INTO Covid_Diagnosis
VALUES (2, '2020-02-12', '2020-02-21');	#check dates format #YY MM DD

-- SELECT * FROM Covid_Diagnosis


#Q3
# pick up from here!
-- An infected person cannot visit any Pub during the isolation period, i.e.,
-- from the diagnosis date and before the end of isolation.

DROP TRIGGER IF EXISTS yesCovid_NoPub;

DELIMITER //
CREATE TRIGGER yesCovid_NoPub
BEFORE INSERT
ON Visit FOR EACH ROW

BEGIN
	DECLARE ender INT;
	
	DECLARE Tstart DATE;
	
	DECLARE Tend DATE;
	
	DECLARE CURS_X CURSOR FOR SELECT DiagnosisDate FROM Covid_Diagnosis cd where PPSN = new.PPSN;
	
	DECLARE CURS_Y CURSOR FOR SELECT IsolationEndDate FROM Covid_Diagnosis cd where PPSN = new.PPSN;
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET ender = 1;

	open CURS_X;
	
	open CURS_Y;
	
	spinDates: LOOP
		fetch CURS_X into Tstart;
		fetch CURS_Y into Tend;
		if (ender =1) 
			then leave spinDates;
		
		elseif (Tstart IS NOT NULL) THEN
			IF (new.StartDateOfVisit <= Tend and Tstart <= new.StartDateOfVisit) THEN 
				SIGNAL SQLSTATE '45000' #error code?
				SET MESSAGE_TEXT = 'STAY AT HOME NO PUBS FOR YOU!'; # if failed at constrainsts refuse insert display message.
			END IF;
		END IF;
	
		END LOOP spinDates;
		CLOSE CURS_X;
		CLOSE CURS_Y;
	
	END;
DELIMITER ;

#Q4

--  In order to reduce the spread of the virus in this hypothetical system a
-- person can only visit Pubs in a restricted area,
-- for the context of this project that
-- would be in the same county of residence or a neighbour county.

DROP TRIGGER IF EXISTS dontGoFar;

delimiter //

CREATE TRIGGER dontGoFar
BEFORE INSERT
ON Visit FOR EACH ROW

BEGIN
	DECLARE MAINTAINANCE varchar(255);
	DECLARE ender INT;
	DECLARE pubCounty varchar(255);
	DECLARE personsNeighbourC varchar(255);
	DECLARE personCounty varchar(255);
	
	DECLARE PubCURS_X CURSOR FOR SELECT PCounty FROM Pub where PLN = new.PLN; # get pub's county
	
	DECLARE Neighbour_cursY CURSOR FOR SELECT County2
									FROM NeighbourCounty
									WHERE County1 IN (
									SELECT PCounty 
									FROM Person
									WHERE PPSN = NEW.PPSN
									); # get the neighbour's county 
	
	DECLARE PersonCurs_Z CURSOR FOR SELECT PCounty FROM Person where PPSN = new.PPSN; #get person's county

	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET ender = 1;
	
	SET MAINTAINANCE := 'False';

	open PubCURS_X;
	open Neighbour_cursY;
	OPEN PersonCurs_Z;
	
	spinCounty: LOOP #OUTER LOOP
			IF (ender = 1) 
				then leave spinCounty;
			END IF;
			FETCH PersonCurs_Z INTO personCounty;
			FETCH PubCURS_X INTO pubCounty;
		
			IF (NEW.PPSN IS NOT NULL) THEN #pub county in county1, neighbour in county2. if Pcounty not in county1 or county 2 then reject
				
				spinNeighbour: LOOP # INNER LOOP
					FETCH Neighbour_cursY INTO  personsNeighbourC;
					IF (ender = 1)
						then leave spinNeighbour;	#ERROR HERE
				
					ELSEIF (personCounty = pubCounty OR personsNeighbourC = pubCounty)THEN 
						SET MAINTAINANCE = 'True';
						LEAVE spinNeighbour;
					END IF;
				END LOOP spinNeighbour;
			END IF;
			END LOOP spinCounty;
			IF (MAINTAINANCE = 'False') THEN
				SIGNAL SQLSTATE '45000' #error code?
				SET MESSAGE_TEXT = 'TOO FAR COME BACK!'; # if failed at constrainsts refuse insert display message.
				END IF;
			CLOSE Neighbour_cursY;
			CLOSE PubCURS_X;
			CLOSE PersonCurs_Z;
			END;

DELIMITER ;

#Q5

-- In order to further reduce the spread of the virus, in this hypothetical
-- system, a person is only allowed to visit a certain number of Pubs in a 24 hour
-- period, i.e., (DailyPubLimit) and of course the same person cannot visit more than 1
-- Pub at the same time.

DROP TRIGGER IF EXISTS pubCap;

DELIMITER //
CREATE TRIGGER pubCap
before INSERT
ON Visit FOR EACH ROW
BEGIN
	DECLARE COUNTS INT;
	DECLARE LIMITS INT;
	DECLARE ender INT;

	DECLARE CURSX CURSOR FOR SELECT DailyPubLimit FROM Person p WHERE PPSN = NEW.PPSN;
	DECLARE CURSY CURSOR FOR SELECT COUNT(PPSN) FROM Visit v WHERE PPSN = NEW.PPSN;
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET ender = 1;
	OPEN CURSX;
	OPEN CURSY;
	SPINLIMITS: LOOP #OUTER LOOP
		FETCH CURSY INTO COUNTS;
		FETCH CURSX INTO LIMITS;
		IF (ENDER =1) THEN
			LEAVE SPINLIMITS;
		ELSEIF(NEW.PPSN IS NOT NULL) THEN
			IF (LIMITS <= COUNTS) THEN
				SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'YOU REACHED YOUR LIMIT! NO MORE PUBS FOR YOU!';
				LEAVE SPINLIMITS;
			END IF;
			END IF;
		END LOOP SPINLIMITS;
		CLOSE CURSX;
		CLOSE CURSY;
END;	
DELIMITER ;

#Q6

-- Create a view (named COVID_NUMBERS) to retrieve the number of COVID
-- cases for each county in the database. This view will output two columns named
-- county and cases.

CREATE OR REPLACE VIEW COVID_NUMBERS AS SELECT count(PPSN) as cases, PCounty as county  FROM Person
where PPSN in (SELECT PPSN from Covid_Diagnosis
)
group by PCounty
;
