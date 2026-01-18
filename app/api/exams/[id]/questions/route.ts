import { NextRequest, NextResponse } from "next/server";
import { getConnection, sql } from "@/lib/db";
import jwt from "jsonwebtoken";
import { Question, Choice } from "@/types";
import { IRecordSet } from "mssql";

const JWT_SECRET =
  process.env.JWT_SECRET || "your-secret-key-change-in-production";

function getStudentFromToken(request: NextRequest) {
  const token = request.cookies.get("auth-token")?.value;
  if (!token) return null;

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { studentId: number };
    return decoded.studentId;
  } catch {
    return null;
  }
}

// NOTE: extractExamId is async now and will await params if it's a Promise
async function extractExamId(
  request: NextRequest,
  params?: { id?: string } | Promise<{ id?: string } | null> | null
) {
  // If params is a Promise, await it (covers Next's async params)
  let resolvedParams: { id?: string } | null = null;
  if (params) {
    // detect promise-like
    if (typeof (params as any).then === "function") {
      resolvedParams = (await params) ?? null;
    } else {
      resolvedParams = params as { id?: string } | null;
    }
  }

  // 1) prefer route params (app router passes context.params)
  let idStr = resolvedParams?.id ?? null;

  // 2) fallback to query string e.g. /api/exams/questions?id=123
  if (!idStr) {
    idStr = request.nextUrl.searchParams.get("id") ?? null;
  }

  // 3) last resort: try to parse from pathname (/api/exams/123/questions)
  if (!idStr) {
    const m = request.nextUrl.pathname.match(/\/exams\/([^/]+)/);
    if (m) idStr = m[1];
  }

  if (!idStr) return NaN;
  const parsed = Number.parseInt(idStr, 10);
  return Number.isNaN(parsed) ? NaN : parsed;
}

export async function GET(
  request: NextRequest,
  context?: { params?: { id?: string } } // still optional for compile-time
) {
  try {
    const studentId = getStudentFromToken(request);
    if (!studentId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // await extractExamId because it may need to await a promised params
    const examId = await extractExamId(request, (context as any)?.params ?? null);
    if (Number.isNaN(examId)) {
      return NextResponse.json({ error: "Invalid exam id" }, { status: 400 });
    }

    const pool = await getConnection();

    // 1) Check access via stored procedure
    const accessResult = await pool
      .request()
      .input("examId", sql.Int, examId)
      .input("studentId", sql.Int, studentId)
      .execute("dbo.usp_CheckExamAccess");

    // If no rows returned -> not found / not assigned
    if (!accessResult.recordset || accessResult.recordset.length === 0) {
      return NextResponse.json({ error: "Exam not found" }, { status: 404 });
    }

    const exam = accessResult.recordset[0];
    const now = new Date();

    // Already completed?
    if (exam.Submission_Time != null) {
      return NextResponse.json(
        { error: "Exam already completed" },
        { status: 400 }
      );
    }

    // Time window checks
    if (now < new Date(exam.Exam_Start_Time)) {
      return NextResponse.json(
        { error: "Exam has not started yet" },
        { status: 400 }
      );
    }
    if (now > new Date(exam.Exam_End_Time)) {
      return NextResponse.json(
        { error: "Exam time has expired" },
        { status: 400 }
      );
    }

    // 2) Get questions + choices via stored procedure (two result sets)
    const qAndCResult = await pool
      .request()
      .input("examId", sql.Int, examId)
      .execute("dbo.usp_GetExamQuestionsWithChoices");

    // Narrow the union at runtime
    const recordsets = Array.isArray(qAndCResult.recordsets)
      ? (qAndCResult.recordsets as IRecordSet<any>[])
      : (Object.values(qAndCResult.recordsets) as IRecordSet<any>[]);

    const questionsResult = (recordsets[0] ?? []) as Question[];
    const choicesResult = (recordsets[1] ?? []) as Choice[];

    // Combine questions with choices
    const questions: Question[] = (questionsResult as Question[]).map(
      (q: Question) => ({
        ...q,
        Choices: (choicesResult as Choice[]).filter(
          (c: Choice) => c.Question_Id === q.Question_Id
        ),
      })
    );

    return NextResponse.json({
      questions,
      examEndTime: exam.Exam_End_Time,
    });
  } catch (error) {
    console.error("Get exam questions error:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}

