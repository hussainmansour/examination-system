import { NextRequest, NextResponse } from 'next/server';
import { getConnection, sql } from '@/lib/db';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';

export async function POST(request: NextRequest) {
  try {
    const { email, password } = await request.json();

    if (!email || !password) {
      return NextResponse.json(
        { error: 'Email and password are required' },
        { status: 400 }
      );
    }

    const pool = await getConnection();

    // Call the stored procedure
    const result = await pool
      .request()
      .input('Email', sql.VarChar(40), email)
      .input('Password', sql.VarChar(255), password)
      .execute('sp_AuthenticateStudent');

    // Check if authentication was successful
    if (result.recordset.length === 0 || result.recordset[0].Student_Id === null) {
      return NextResponse.json(
        { error: 'Invalid credentials' },
        { status: 401 }
      );
    }

    const student = result.recordset[0];

    // Create JWT token
    const token = jwt.sign(
      {
        studentId: student.Student_Id,
        email: student.Student_Email,
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    const response = NextResponse.json({
      success: true,
      student: {
        id: student.Student_Id,
        firstName: student.Student_Fname,
        lastName: student.Student_Lname,
        email: student.Student_Email,
        trackId: student.Track_Id,
      },
    });

    // Set HTTP-only cookie
    response.cookies.set('auth-token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 86400, // 24 hours
    });

    return response;
  } catch (error) {
    console.error('Login error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}