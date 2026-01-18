export interface Student {
  Student_Id: number;
  Student_Fname: string;
  Student_Lname: string;
  Student_Email: string;
  Student_Password: string;
  Student_BD: Date;
  Student_Phone: string;
  Track_Id: string;
}

export interface Exam {
  Exam_Id: number;
  Exam_Total_Grade: number;
  Course_Id: number;
  Course_Name: string;
  Exam_Start_Time: Date;
  Exam_End_Time: Date;
  Student_Exam_Achieved_Grade?: number;
  IsCompleted?: boolean;
}

export interface Question {
  Question_Id: number;
  Question_Type: 'MCQ' | 'TF';
  Question_Body: string;
  Question_Weight: number;
  Question_Order: number;
  Choices?: Choice[];
}

export interface Choice {
  Question_Id: number;
  Choice_Label: string;
  Choice_Body: string;
}

export interface StudentAnswer {
  Question_Id: number;
  Student_Answer: string;
}

export interface ExamSubmission {
  Student_Id: number;
  Exam_Id: number;
  Answers: StudentAnswer[];
}