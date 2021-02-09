
-- 1.	Create Table Logs

CREATE TABLE Logs
(
LogId int IDENTITY,
AccountId int,
OldSum money,
NewSum money,
CONSTRAINT PK_Logs PRIMARY KEY(LogId),
CONSTRAINT FK_Logs_Accounts FOREIGN KEY(AccountId) REFERENCES Accounts(Id)
)

GO

CREATE TRIGGER tr_BalanceChange ON Accounts AFTER UPDATE
AS
BEGIN
	INSERT INTO Logs(AccountId, OldSum, NewSum)
	SELECT i.Id, d.Balance, i.Balance 
	FROM inserted AS i
	INNER JOIN deleted AS d
	ON i.Id = d.Id
END


-- 2.	Create Table Emails

CREATE TABLE NotificationEmails
(
	Id INT PRIMARY KEY IDENTITY,
	Recipient INT,
	[Subject] VARCHAR(MAX),
	Body VARCHAR(MAX)
)

GO

CREATE TRIGGER tr_EmailNotificationOnBalanceChange ON Logs AFTER INSERT
AS
BEGIN
	INSERT INTO NotificationEmails(Recipient, Subject, Body)
	SELECT	AccountId, 
		CONCAT('Balance change for account: ', AccountId), 
		CONCAT('On ', GETDATE(), ' your balance was changed from ', OldSum, ' to ', NewSum, '.') 
	FROM inserted
END


-- 3.	Deposit Money

CREATE PROCEDURE usp_DepositMoney(@accountId INT, @moneyAmount MONEY)
AS
	BEGIN TRANSACTION
		UPDATE Accounts
		SET Balance += @moneyAmount
		WHERE Id = @accountId
	COMMIT

GO


-- 4.	Withdraw Money

CREATE PROCEDURE usp_WithdrawMoney(@accountId INT, @moneyAmount MONEY)
AS
BEGIN TRANSACTION

	UPDATE Accounts
	SET Balance -= @moneyAmount
	WHERE Id = @accountId
	
	DECLARE @currentBalance money = (SELECT Balance FROM Accounts WHERE Id = @accountId)

	IF(@currentBalance < 0)
		BEGIN
			ROLLBACK
			RAISERROR('Insufficient funds!', 16, 1)
			RETURN
		END
	ELSE
		BEGIN
			COMMIT
		END

GO


-- 5.	Money Transfer

CREATE PROCEDURE usp_TransferMoney(@senderId INT, @receiverId INT, @amount MONEY)
AS
BEGIN TRANSACTION

IF(@amount < 0)
	BEGIN
		ROLLBACK
		RAISERROR('Amount is less then 0!', 16, 1)
		RETURN
	END

EXEC usp_WithdrawMoney @senderId, @amount
EXEC usp_DepositMoney @receiverId, @amount

COMMIT