-- Examination_System_Full_Corrected_Script.sql
-- Corrected, parent-first, idempotent test-data loader with transactions and error handling.
-- Usage: run this in the Examination_System database context.

USE Examination_System;
GO

SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- =========================================================
    -- 1) CLEANUP: delete in child->parent order
    -- =========================================================
    DELETE FROM STUDENT_ANSWERS;
    DELETE FROM STUDENT_EXAM;
    DELETE FROM EXAM_QUESTIONS;
    DELETE FROM EXAMS;
    DELETE FROM CHOICES;
    DELETE FROM QUESTIONS;
    DELETE FROM TOPICS;
    DELETE FROM INSTRUCTOR_COURSE;
    DELETE FROM COURSE;
    DELETE FROM STUDENT;
    DELETE FROM INSTRUCTOR;
    DELETE FROM TRACK;
    DELETE FROM BRANCH;

    -- =========================================================
    -- 2) RESEED identity columns (safe for test data)
    -- =========================================================
    -- NOTE: if a table does not have IDENTITY, DBCC CHECKIDENT will return an error —
    -- ignore those errors or remove lines for tables without identity.
    IF OBJECT_ID('dbo.STUDENT', 'U') IS NOT NULL
        DBCC CHECKIDENT ('STUDENT', RESEED, 0);
    IF OBJECT_ID('dbo.INSTRUCTOR', 'U') IS NOT NULL
        DBCC CHECKIDENT ('INSTRUCTOR', RESEED, 0);
    IF OBJECT_ID('dbo.COURSE', 'U') IS NOT NULL
        DBCC CHECKIDENT ('COURSE', RESEED, 0);
    IF OBJECT_ID('dbo.TOPICS', 'U') IS NOT NULL
        DBCC CHECKIDENT ('TOPICS', RESEED, 0);
    IF OBJECT_ID('dbo.QUESTIONS', 'U') IS NOT NULL
        DBCC CHECKIDENT ('QUESTIONS', RESEED, 0);
    IF OBJECT_ID('dbo.EXAMS', 'U') IS NOT NULL
        DBCC CHECKIDENT ('EXAMS', RESEED, 0);

    -- =========================================================
    -- 3) INSERT PARENTS: BRANCH -> TRACK -> INSTRUCTOR -> COURSE
    -- =========================================================

    -- Branches
    INSERT INTO BRANCH (Branch_Id, Branch_Address) VALUES
    ('BR001', 'Cairo, Nasr City'),
    ('BR002', 'Alexandria, Smouha');

    -- Tracks
    INSERT INTO TRACK (Track_Id, Track_Name, Branch_Id) VALUES
    ('CS', 'Computer Science', 'BR001'),
    ('AI', 'AI Track', 'BR001'),
    ('DS', 'Data Science', 'BR002');

    -- Instructors (will receive Instructor_Id = 1, 2 after reseed)
    INSERT INTO INSTRUCTOR (Instructor_Fname, Instructor_Lname, Instructor_Email, Instructor_Phone, Instructor_Salary)
    VALUES
    ('Dr. Mahmoud', 'Ali', 'mahmoud.ali@example.com', '01123456789', 15000),
    ('Dr. Fatma', 'Kamel', 'fatma.kamel@example.com', '01187654321', 18000);

    -- Courses: use explicit IDs for stability in test-data (100,200,300)
    SET IDENTITY_INSERT COURSE ON;
    INSERT INTO COURSE (Course_Id, Course_Name, Course_Description, Track_Id)
    VALUES
    (100, 'Database Systems', 'Introduction to relational databases, SQL, and database design principles', 'CS'),
    (200, 'Machine Learning', 'Fundamentals of machine learning algorithms and practical applications', 'AI'),
    (300, 'Web Development', 'Full-stack web development using modern frameworks and technologies', 'CS');
    SET IDENTITY_INSERT COURSE OFF;

    -- ensure identity counter for COURSE is at least the max explicit id
    DBCC CHECKIDENT ('COURSE', RESEED, 300);

    -- =========================================================
    -- 4) CHILD: INSTRUCTOR_COURSE (references INSTRUCTOR and COURSE)
    -- =========================================================
    -- At this point Instructor_Id 1 and 2 must exist (inserted above)
    INSERT INTO INSTRUCTOR_COURSE (Instructor_Id, Course_Id)
    VALUES (1, 100), (1, 300), (2, 200);

    -- =========================================================
    -- 5) TOPICS
    -- =========================================================
    INSERT INTO TOPICS (Topic_Name, Course_Id)
    VALUES
    -- Database Systems Topics
    ('SQL Fundamentals', 100),
    ('Database Design', 100),
    ('Normalization', 100),
    -- Machine Learning Topics
    ('Supervised Learning', 200),
    ('Neural Networks', 200),
    ('Model Evaluation', 200),
    -- Web Development Topics
    ('HTML & CSS', 300),
    ('JavaScript Basics', 300),
    ('REST APIs', 300);

    -- =========================================================
    -- 6) QUESTIONS (insert in the order you expect their IDs to be)
    --    Database Systems (expected Question_Id 1..14)
    --    Machine Learning (15..24)
    --    Web Development (25..34)
    -- =========================================================
    INSERT INTO QUESTIONS (Question_Type, Question_Body, Question_Weight, Question_Model_Answer, Course_Id)
    VALUES
    -- Database Systems (1-14)
    ('MCQ', 'What does SQL stand for?', 10, 'B', 100),
    ('MCQ', 'Which SQL command is used to retrieve data from a database?', 10, 'A', 100),
    ('MCQ', 'What is a primary key?', 10, 'C', 100),
    ('MCQ', 'Which normal form removes partial dependencies?', 10, 'B', 100),
    ('MCQ', 'What does the JOIN clause do in SQL?', 10, 'A', 100),
    ('MCQ', 'Which data type is used to store large text in SQL Server?', 10, 'D', 100),
    ('MCQ', 'What is the purpose of an index in a database?', 10, 'B', 100),
    ('MCQ', 'Which clause is used to filter results in SQL?', 10, 'C', 100),
    ('TF', 'A foreign key must always reference a primary key in another table.', 10, 'T', 100),
    ('TF', 'The DELETE command removes the table structure from the database.', 10, 'F', 100),
    ('TF', 'NULL values are the same as zero or empty strings.', 10, 'F', 100),
    ('TF', 'A table can have multiple primary keys.', 10, 'F', 100),
    ('TF', 'The GROUP BY clause is used with aggregate functions.', 10, 'T', 100),
    ('TF', 'INNER JOIN returns all records from both tables.', 10, 'F', 100),

    -- Machine Learning (15-24)
    ('MCQ', 'What is supervised learning?', 10, 'A', 200),
    ('MCQ', 'Which algorithm is used for classification?', 10, 'B', 200),
    ('MCQ', 'What does overfitting mean?', 10, 'C', 200),
    ('MCQ', 'What is the activation function in neural networks?', 10, 'D', 200),
    ('MCQ', 'Which metric measures classification accuracy?', 10, 'A', 200),
    ('TF', 'Neural networks are inspired by the human brain.', 10, 'T', 200),
    ('TF', 'Unsupervised learning requires labeled data.', 10, 'F', 200),
    ('TF', 'Cross-validation helps prevent overfitting.', 10, 'T', 200),
    ('TF', 'Linear regression is used for classification problems.', 10, 'F', 200),
    ('TF', 'Deep learning is a subset of machine learning.', 10, 'T', 200),

    -- Web Development (25-34)
    ('MCQ', 'What does HTML stand for?', 10, 'B', 300),
    ('MCQ', 'Which CSS property changes text color?', 10, 'A', 300),
    ('MCQ', 'What is the purpose of JavaScript?', 10, 'C', 300),
    ('MCQ', 'What does REST API stand for?', 10, 'D', 300),
    ('MCQ', 'Which HTTP method is used to retrieve data?', 10, 'A', 300),
    ('TF', 'HTML is a programming language.', 10, 'F', 300),
    ('TF', 'CSS is used for styling web pages.', 10, 'T', 300),
    ('TF', 'JavaScript can only run in web browsers.', 10, 'F', 300),
    ('TF', 'JSON is a data format commonly used in APIs.', 10, 'T', 300),
    ('TF', 'HTTP is a stateless protocol.', 10, 'T', 300);

    -- after inserting questions, make sure identity seed is up to date
    DECLARE @maxq INT;
SELECT @maxq = ISNULL(MAX(Question_Id),0) FROM QUESTIONS;
DBCC CHECKIDENT ('QUESTIONS', RESEED, @maxq);

    -- =========================================================
    -- 7) CHOICES for MCQs
    -- =========================================================
    INSERT INTO CHOICES (Choice_Label, Question_Id, Choice_Body)
    VALUES
    -- Q1
    ('A', 1, 'Structured Question Language'),
    ('B', 1, 'Structured Query Language'),
    ('C', 1, 'Simple Query Language'),
    ('D', 1, 'System Query Language'),
    -- Q2
    ('A', 2, 'SELECT'),
    ('B', 2, 'GET'),
    ('C', 2, 'RETRIEVE'),
    ('D', 2, 'FETCH'),
    -- Q3
    ('A', 3, 'A key that opens the database'),
    ('B', 3, 'Any column in a table'),
    ('C', 3, 'A unique identifier for each record'),
    ('D', 3, 'A foreign reference'),
    -- Q4
    ('A', 4, '1NF'),
    ('B', 4, '2NF'),
    ('C', 4, '3NF'),
    ('D', 4, 'BCNF'),
    -- Q5
    ('A', 5, 'Combines rows from two or more tables'),
    ('B', 5, 'Deletes duplicate rows'),
    ('C', 5, 'Creates a new table'),
    ('D', 5, 'Updates existing records'),
    -- Q6
    ('A', 6, 'VARCHAR(50)'),
    ('B', 6, 'CHAR'),
    ('C', 6, 'INT'),
    ('D', 6, 'TEXT'),
    -- Q7
    ('A', 7, 'To store data'),
    ('B', 7, 'To improve query performance'),
    ('C', 7, 'To create relationships'),
    ('D', 7, 'To delete records'),
    -- Q8
    ('A', 8, 'SELECT'),
    ('B', 8, 'FROM'),
    ('C', 8, 'WHERE'),
    ('D', 8, 'ORDER BY'),

    -- Machine Learning MCQs (15-19)
    ('A', 15, 'Learning with labeled training data'),
    ('B', 15, 'Learning without any data'),
    ('C', 15, 'Learning by trial and error'),
    ('D', 15, 'Learning from unlabeled data'),
    ('A', 16, 'Linear Regression'),
    ('B', 16, 'Logistic Regression'),
    ('C', 16, 'K-Means'),
    ('D', 16, 'PCA'),
    ('A', 17, 'Model is too simple'),
    ('B', 17, 'Model generalizes well'),
    ('C', 17, 'Model memorizes training data'),
    ('D', 17, 'Model has high bias'),
    ('A', 18, 'Database function'),
    ('B', 18, 'Linear function only'),
    ('C', 18, 'Sorting function'),
    ('D', 18, 'Introduces non-linearity'),
    ('A', 19, 'Confusion Matrix'),
    ('B', 19, 'Standard Deviation'),
    ('C', 19, 'Variance'),
    ('D', 19, 'Mean'),

    -- Web Development MCQs (25-29)
    ('A', 25, 'Hyper Text Markup Loop'),
    ('B', 25, 'Hyper Text Markup Language'),
    ('C', 25, 'High Tech Modern Language'),
    ('D', 25, 'Home Tool Markup Language'),
    ('A', 26, 'color'),
    ('B', 26, 'text-color'),
    ('C', 26, 'font-color'),
    ('D', 26, 'text-style'),
    ('A', 27, 'Style web pages'),
    ('B', 27, 'Structure content'),
    ('C', 27, 'Add interactivity'),
    ('D', 27, 'Store data'),
    ('A', 28, 'Rapid Exchange System Transfer'),
    ('B', 28, 'Remote Execution Service Technology'),
    ('C', 28, 'Real Estate Software Tools'),
    ('D', 28, 'Representational State Transfer'),
    ('A', 29, 'GET'),
    ('B', 29, 'POST'),
    ('C', 29, 'PUT'),
    ('D', 29, 'DELETE');

    -- =========================================================
    -- 8) EXAMS (explicit IDs for stability) and EXAM_QUESTIONS
    -- =========================================================
    SET IDENTITY_INSERT EXAMS ON;
    INSERT INTO EXAMS (Exam_Id, Exam_Total_Grade, Course_Id, Exam_Start_Time, Exam_End_Time)
    VALUES
    (1, 100, 100, '2026-01-18 18:00:00', '2026-01-18 21:00:00'),
    (2, 100, 100, '2026-05-15 09:00:00', '2026-05-15 12:00:00'),
    (3, 100, 200, '2025-02-05 10:00:00', '2025-02-05 12:00:00'),
    (4, 100, 300, '2025-05-20 14:00:00', '2025-05-20 17:00:00');
    SET IDENTITY_INSERT EXAMS OFF;

    DBCC CHECKIDENT ('EXAMS', RESEED, 4);

    -- EXAM_QUESTIONS: ensure QUESTIONS exist before these inserts
    INSERT INTO EXAM_QUESTIONS (Exam_Id, Question_Id, Question_Order)
    VALUES
    -- Exam 1: Database Systems Midterm (use question ids 1..8/9 depending on your design)
    (1, 1, 1), (1, 2, 2), (1, 3, 3), (1, 4, 4), (1, 5, 5), (1, 9, 6), (1, 10, 7), (1, 11, 8),

    -- Exam 2: Database Systems Final
    (2, 6, 1), (2, 7, 2), (2, 8, 3), (2, 12, 4), (2, 13, 5), (2, 14, 6),

    -- Exam 3: Machine Learning Midterm
    (3, 15, 1), (3, 16, 2), (3, 17, 3), (3, 18, 4), (3, 19, 5), (3, 20, 6), (3, 21, 7), (3, 22, 8),

    -- Exam 4: Web Development Final
    (4, 25, 1), (4, 26, 2), (4, 27, 3), (4, 28, 4), (4, 29, 5), (4, 30, 6), (4, 31, 7), (4, 32, 8), (4, 33, 9), (4, 34, 10);

    -- =========================================================
    -- 9) STUDENTS and STUDENT_EXAM
    -- =========================================================
    INSERT INTO STUDENT (Student_Fname, Student_Lname, Student_Email, Student_Password, Student_BD, Student_Phone, Track_Id)
    VALUES
    ('Ahmed', 'Hassan', 'ahmed.hassan@example.com', CONVERT(VARBINARY(32), HASHBYTES('SHA2_256', 'password123')), '2000-05-15', '01012345678', 'CS'),
    ('Sara', 'Mohamed', 'sara.mohamed@example.com', CONVERT(VARBINARY(32), HASHBYTES('SHA2_256', 'password456')), '2001-08-22', '01098765432', 'AI');

    DECLARE @maxs INT;
SELECT @maxs = ISNULL(MAX(Student_Id),0) FROM STUDENT;
DBCC CHECKIDENT ('STUDENT', RESEED, @maxs);

    -- STUDENT_EXAM assignments
    INSERT INTO STUDENT_EXAM (Student_Id, Exam_Id, Student_Exam_Achieved_Grade)
    VALUES
    (1, 1, 0), -- Ahmed takes Database Midterm
    (1, 2, 0), -- Ahmed takes Database Final
    (1, 4, 0), -- Ahmed takes Web Development Final
    (2, 1, 0), -- Sara takes Database Midterm
    (2, 3, 0); -- Sara takes Machine Learning Midterm

    -- =========================================================
    -- 10) FINISH
    -- =========================================================
    COMMIT TRANSACTION;
    PRINT 'Test data inserted successfully!';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    DECLARE @ErrNum INT = ERROR_NUMBER();
    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    PRINT 'ERROR: ' + CAST(@ErrNum AS NVARCHAR(20)) + ' - ' + @ErrMsg;
    THROW; -- re-throw so calling client sees the error
END CATCH;
GO
