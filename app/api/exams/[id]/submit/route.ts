import { NextRequest, NextResponse } from 'next/server';
import { getConnection, sql } from '@/lib/db';
import jwt from 'jsonwebtoken';

const JWT_SECRET =
  process.env.JWT_SECRET || 'your-secret-key-change-in-production';

function getStudentFromToken(request: NextRequest) {
  const token = request.cookies.get('auth-token')?.value;
  if (!token) return null;

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { studentId: number };
    return decoded.studentId;
  } catch {
    return null;
  }
}

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ id: string }> } // params is async
) {
  try {
    const studentId = getStudentFromToken(request);
    if (!studentId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // unwrap params
    const { id } = await context.params;
    const examId = Number.parseInt(id, 10);

    if (Number.isNaN(examId)) {
      return NextResponse.json({ error: 'Invalid exam id' }, { status: 400 });
    }

    const { answers } = await request.json();

    const answersJson = JSON.stringify(
      answers.map((a: any) => ({
        QuestionId: a.Question_Id,
        StudentAnswer: a.Student_Answer,
      }))
    );

    const pool = await getConnection();

    const result = await pool
      .request()
      .input('studentId', sql.Int, studentId)
      .input('examId', sql.Int, examId)
      .input('answersJson', sql.NVarChar(sql.MAX), answersJson)
      .execute('dbo.usp_SubmitExamAnswers_JSON');

    const grade = result.recordset?.[0]?.Grade ?? 0;

    return NextResponse.json({ success: true, grade });
  } catch (error) {
    console.error('Submit exam error (JSON):', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
