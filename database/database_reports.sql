-- Active: 1765720541948@@127.0.0.1@1433@Examination_System
USE Examination_System;
GO
-- 1) Students by Department (Track)
IF OBJECT_ID('dbo.report_GetStudentsByTrack','P') IS NOT NULL
    DROP PROCEDURE dbo.report_GetStudentsByTrack;
GO
CREATE PROCEDURE dbo.report_GetStudentsByTrack
    @TrackId VARCHAR(2)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.Student_Id,
        s.Student_Fname,
        s.Student_Lname,
        s.Student_Email,
        s.Student_Phone,
        s.Student_BD,
        s.Track_Id,
        t.Track_Name,
        t.Branch_Id,
        b.Branch_Address
    FROM STUDENT s
    JOIN TRACK t ON s.Track_Id = t.Track_Id
    LEFT JOIN BRANCH b ON t.Branch_Id = b.Branch_Id
    WHERE s.Track_Id = @TrackId;
END;
GO

-- 2) Grades of a student in all courses (per exam + per-course averages)
IF OBJECT_ID('dbo.report_GetStudentGradesAllCourses','P') IS NOT NULL
    DROP PROCEDURE dbo.report_GetStudentGradesAllCourses;
GO
CREATE PROCEDURE dbo.report_GetStudentGradesAllCourses
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Result set 1: per-exam details
    SELECT
        c.Course_Id,
        c.Course_Name,
        e.Exam_Id,
        e.Exam_Total_Grade,
        se.Student_Exam_Achieved_Grade,
        CASE WHEN e.Exam_Total_Grade = 0 THEN NULL
             ELSE CAST(se.Student_Exam_Achieved_Grade * 100.0 / e.Exam_Total_Grade AS DECIMAL(6,2)) END AS Percentage,
        se.Submission_Time
    FROM STUDENT_EXAM se
    JOIN EXAMS e ON se.Exam_Id = e.Exam_Id
    JOIN COURSE c ON e.Course_Id = c.Course_Id
    WHERE se.Student_Id = @StudentId
    ORDER BY c.Course_Id, e.Exam_Id;
END;
GO

-- 3) Instructor's courses and number of students per course
IF OBJECT_ID('dbo.report_GetInstructorCoursesAndStudentCount','P') IS NOT NULL
    DROP PROCEDURE dbo.report_GetInstructorCoursesAndStudentCount;
GO
CREATE PROCEDURE dbo.report_GetInstructorCoursesAndStudentCount
    @InstructorId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.Course_Id,
        c.Course_Name,
        COUNT(DISTINCT s.Student_Id) AS Student_Count
    FROM INSTRUCTOR_COURSE ic
    JOIN COURSE c ON ic.Course_Id = c.Course_Id
    LEFT JOIN STUDENT s ON s.Track_Id = c.Track_Id
    WHERE ic.Instructor_Id = @InstructorId
    GROUP BY c.Course_Id, c.Course_Name
    ORDER BY c.Course_Id;
END;
GO

-- 4) Topics for a course
IF OBJECT_ID('dbo.report_GetCourseTopics','P') IS NOT NULL
    DROP PROCEDURE dbo.report_GetCourseTopics;
GO
CREATE PROCEDURE dbo.report_GetCourseTopics
    @CourseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Topic_Id,
        Topic_Name
    FROM TOPICS
    WHERE Course_Id = @CourseId
    ORDER BY Topic_Id;
END;
GO

-- 5) Questions in an exam and their choices (freeform report)
IF OBJECT_ID('dbo.report_GetExamQuestionsWithChoices','P') IS NOT NULL
    DROP PROCEDURE dbo.report_GetExamQuestionsWithChoices;
GO
CREATE PROCEDURE dbo.report_GetExamQuestionsWithChoices
    @ExamId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        q.Question_Body,
        q.Question_Weight,
        c.Choice_Label,
        c.Choice_Body
    FROM EXAM_QUESTIONS eq
    JOIN QUESTIONS q ON eq.Question_Id = q.Question_Id
    LEFT JOIN CHOICES c ON q.Question_Id = c.Question_Id
    WHERE eq.Exam_Id = @ExamId
    ORDER BY eq.Question_Order, c.Choice_Label;
END;
GO

-- 6) Questions in an exam with a student's answers (and correctness + choices aggregated)
IF OBJECT_ID('dbo.report_GetExamQuestionsWithStudentAnswers','P') IS NOT NULL
    DROP PROCEDURE dbo.report_GetExamQuestionsWithStudentAnswers;
GO

-- CREATE PROCEDURE dbo.report_GetExamQuestionsWithStudentAnswers
--     @ExamId INT,
--     @StudentId INT
-- AS
-- BEGIN
--     SET NOCOUNT ON;

--     SELECT
--         eq.Question_Order,
--         q.Question_Id,
--         q.Question_Type,
--         q.Question_Body,
--         q.Question_Weight,
--         q.Question_Model_Answer,
--         sa.Student_Answer,
--         CASE 
--             WHEN sa.Student_Answer IS NULL THEN NULL
--             WHEN sa.Student_Answer = q.Question_Model_Answer THEN 1
--             ELSE 0
--         END AS IsCorrect,
--         -- choice-level columns
--         c.Choice_Label,
--         c.Choice_Body,
--         CASE WHEN c.Choice_Label = q.Question_Model_Answer THEN 1 ELSE 0 END AS IsModelAnswer,
--         CASE WHEN c.Choice_Label = sa.Student_Answer THEN 1 ELSE 0 END AS IsStudentSelected
--     FROM EXAM_QUESTIONS eq
--     JOIN QUESTIONS q ON eq.Question_Id = q.Question_Id
--     LEFT JOIN CHOICES c ON q.Question_Id = c.Question_Id
--     LEFT JOIN STUDENT_ANSWERS sa
--         ON sa.Exam_Id = eq.Exam_Id
--         AND sa.Question_Id = eq.Question_Id
--         AND sa.Student_Id = @StudentId
--     WHERE eq.Exam_Id = @ExamId
--     ORDER BY eq.Question_Order, c.Choice_Label;
-- END;
-- GO

CREATE PROCEDURE dbo.report_GetExamQuestionsWithStudentAnswers
    @ExamId INT,
    @StudentId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        eq.Question_Order,
        q.Question_Id,
        q.Question_Type,
        q.Question_Body,
        q.Question_Weight,
        q.Question_Model_Answer,
        sa.Student_Answer,
        CASE 
            WHEN sa.Student_Answer IS NULL THEN NULL
            WHEN sa.Student_Answer = q.Question_Model_Answer THEN 1
            ELSE 0
        END AS IsCorrect,
        -- aggregated choices (multi-line), marks model and selected choices
        STRING_AGG(
            c.Choice_Label + '. ' + c.Choice_Body
            + CASE WHEN c.Choice_Label = q.Question_Model_Answer THEN ' [MODEL]' ELSE '' END
            + CASE WHEN c.Choice_Label = sa.Student_Answer THEN ' [SELECTED]' ELSE '' END
            , CHAR(13) + CHAR(10)
        ) WITHIN GROUP (ORDER BY c.Choice_Label) AS Choices
    FROM EXAM_QUESTIONS eq
    JOIN QUESTIONS q ON eq.Question_Id = q.Question_Id
    LEFT JOIN CHOICES c ON q.Question_Id = c.Question_Id
    LEFT JOIN STUDENT_ANSWERS sa
        ON sa.Exam_Id = eq.Exam_Id
        AND sa.Question_Id = eq.Question_Id
        AND sa.Student_Id = @StudentId
    WHERE eq.Exam_Id = @ExamId
    GROUP BY
        eq.Question_Order, q.Question_Id, q.Question_Type, q.Question_Body, q.Question_Weight, q.Question_Model_Answer, sa.Student_Answer
    ORDER BY eq.Question_Order;
END;
GO




-- 1
EXEC dbo.report_GetStudentsByTrack @TrackId = 'AI';

-- 2
EXEC dbo.report_GetStudentGradesAllCourses @StudentId = 1;

-- 3
EXEC dbo.report_GetInstructorCoursesAndStudentCount @InstructorId = 1;

-- 4
EXEC dbo.report_GetCourseTopics @CourseId = 100;

-- 5
EXEC dbo.report_GetExamQuestionsWithChoices @ExamId = 1;

-- 6
EXEC dbo.report_GetExamQuestionsWithStudentAnswers @ExamId = 1, @StudentId = 1;
