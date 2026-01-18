
USE Examination_System;

-- Stored Procedure to authenticate a student
GO
CREATE PROCEDURE sp_AuthenticateStudent
    @Email VARCHAR(40),
    @Password VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StoredPasswordHash VARBINARY(32);
    DECLARE @InputPasswordHash VARBINARY(32);
    
    -- Get the stored password hash for the email
    SELECT @StoredPasswordHash = Student_Password
    FROM STUDENT
    WHERE Student_Email = @Email;
    
    -- If no user found, return empty result
    IF @StoredPasswordHash IS NULL
    BEGIN
        SELECT NULL AS Student_Id;
        RETURN;
    END
    
    -- Hash the input password using SHA2_256
    SET @InputPasswordHash = HASHBYTES('SHA2_256', @Password);
    
    -- Compare the hashes
    IF @StoredPasswordHash = @InputPasswordHash
    BEGIN
        -- Return student data if password matches
        SELECT 
            Student_Id,
            Student_Fname,
            Student_Lname,
            Student_Email,
            Track_Id
        FROM STUDENT
        WHERE Student_Email = @Email;
    END
    ELSE
    BEGIN
        -- Return empty result if password doesn't match
        SELECT NULL AS Student_Id;
    END
END

-- Stored Procedure to get exams for a student by Student_Id
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetStudentExamsByStudentId
    @studentId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Validate student exists
    IF NOT EXISTS (SELECT 1 FROM STUDENT WHERE Student_Id = @studentId)
    BEGIN
        RAISERROR('Student ID %d does not exist.', 16, 1, @studentId);
        RETURN;
    END
    
    -- Get all exams for the student's track
    SELECT 
        e.Exam_Id,
        e.Exam_Total_Grade,
        c.Course_Id,
        c.Course_Name,
        e.Exam_Start_Time,
        e.Exam_End_Time,
        se.Student_Exam_Achieved_Grade,
        CASE 
            WHEN se.Student_Id IS NOT NULL THEN 1
            ELSE 0
        END AS IsCompleted
    FROM 
        STUDENT s
        INNER JOIN TRACK t ON s.Track_Id = t.Track_Id
        INNER JOIN COURSE c ON c.Track_Id = t.Track_Id
        INNER JOIN EXAMS e ON e.Course_Id = c.Course_Id
        LEFT JOIN STUDENT_EXAM se ON se.Exam_Id = e.Exam_Id AND se.Student_Id = s.Student_Id
    WHERE 
        s.Student_Id = @studentId
    ORDER BY 
        e.Exam_Start_Time DESC;
END
GO


USE Examination_System;
GO

-- Check if the exam is accessible for the student
CREATE OR ALTER PROCEDURE dbo.usp_CheckExamAccess
    @examId INT,
    @studentId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        e.Exam_Start_Time,
        e.Exam_End_Time,
        se.Submission_Time
    FROM EXAMS e
    LEFT JOIN STUDENT_EXAM se ON e.Exam_Id = se.Exam_Id
    WHERE e.Exam_Id = @examId
      AND se.Student_Id = @studentId;
END;
GO

-- 2) Get exam questions + choices in two result sets
CREATE OR ALTER PROCEDURE dbo.usp_GetExamQuestionsWithChoices
    @examId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Questions resultset
    SELECT 
        q.Question_Id,
        q.Question_Type,
        q.Question_Body,
        q.Question_Weight,
        eq.Question_Order
    FROM QUESTIONS q
    INNER JOIN EXAM_QUESTIONS eq ON q.Question_Id = eq.Question_Id
    WHERE eq.Exam_Id = @examId
    ORDER BY eq.Question_Order;

    -- Choices resultset (for any question belonging to the exam)
    SELECT 
        c.Question_Id,
        c.Choice_Label,
        c.Choice_Body
    FROM CHOICES c
    INNER JOIN EXAM_QUESTIONS eq2 ON c.Question_Id = eq2.Question_Id
    WHERE eq2.Exam_Id = @examId
    ORDER BY c.Question_Id, c.Choice_Label;
END;
GO


USE Examination_System;
GO


-- Submit exam answers and compute grade
CREATE OR ALTER PROCEDURE dbo.usp_SubmitExamAnswers_JSON
    @studentId INT,
    @examId INT,
    @answersJson NVARCHAR(MAX)  -- expect JSON array: [{ "QuestionId":1, "StudentAnswer":"A" }, ...]
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insert answers from JSON
        INSERT INTO STUDENT_ANSWERS (Student_Id, Exam_Id, Question_Id, Student_Answer)
        SELECT @studentId, @examId, a.QuestionId, a.StudentAnswer
        FROM OPENJSON(@answersJson)
        WITH (
            QuestionId INT '$.QuestionId',
            StudentAnswer VARCHAR(4000) '$.StudentAnswer'
        ) AS a;

        -- Compute total score
        DECLARE @totalScore INT;
        SELECT @totalScore = ISNULL(SUM(q.Question_Weight), 0)
        FROM OPENJSON(@answersJson)
        WITH (
            QuestionId INT '$.QuestionId',
            StudentAnswer VARCHAR(4000) '$.StudentAnswer'
        ) AS a
        INNER JOIN QUESTIONS q ON q.Question_Id = a.QuestionId
        WHERE UPPER(ISNULL(a.StudentAnswer, '')) = UPPER(ISNULL(q.Question_Model_Answer, ''));

        -- Update STUDENT_EXAM
        UPDATE STUDENT_EXAM
        SET Student_Exam_Achieved_Grade = @totalScore,
            Submission_Time = GETDATE()
        WHERE Student_Id = @studentId AND Exam_Id = @examId;

        COMMIT TRANSACTION;

        SELECT @totalScore AS Grade;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO



