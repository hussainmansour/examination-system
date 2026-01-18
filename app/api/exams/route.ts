import { NextRequest, NextResponse } from 'next/server';
import { getConnection, sql } from '@/lib/db';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

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

export async function GET(request: NextRequest) {
  try {
    const studentId = getStudentFromToken(request);

    if (!studentId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const pool = await getConnection();

    // Call stored procedure instead of inline query
    const result = await pool
      .request()
      .input('studentId', sql.Int, studentId)
      .execute('dbo.usp_GetStudentExamsByStudentId');

    return NextResponse.json({
      exams: result.recordset,
    });
  } catch (error) {
    console.error('Get exams error:', error);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
