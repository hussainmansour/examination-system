'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Exam } from '@/types';
import { format } from 'date-fns';

export default function DashboardPage() {
  const [exams, setExams] = useState<Exam[]>([]);
  const [loading, setLoading] = useState(true);
  const [student, setStudent] = useState<any>(null);
  const router = useRouter();

  useEffect(() => {
    const studentData = localStorage.getItem('student');
    if (!studentData) {
      router.push('/');
      return;
    }
    setStudent(JSON.parse(studentData));

    fetchExams();
  }, [router]);

  const fetchExams = async () => {
    try {
      const response = await fetch('/api/exams');
      if (!response.ok) {
        if (response.status === 401) {
          router.push('/');
          return;
        }
        throw new Error('Failed to fetch exams');
      }

      const data = await response.json();
      setExams(data.exams);
    } catch (error) {
      console.error('Error fetching exams:', error);
    } finally {
      setLoading(false);
    }
  };

  const canStartExam = (exam: Exam) => {
    const now = new Date();
    const startTime = new Date(exam.Exam_Start_Time);
    const endTime = new Date(exam.Exam_End_Time);
    return now >= startTime && now <= endTime && !exam.IsCompleted;
  };

  const getExamStatus = (exam: Exam) => {
    const now = new Date();
    const startTime = new Date(exam.Exam_Start_Time);
    const endTime = new Date(exam.Exam_End_Time);
   
    if (exam.IsCompleted) {
      return { text: 'Completed', color: 'bg-green-100 text-green-800' };
    }
    if (now < startTime) {
      return { text: 'Not Started', color: 'bg-yellow-100 text-yellow-800' };
    }
    if (now > endTime) {
      return { text: 'Expired', color: 'bg-red-100 text-red-800' };
    }
    return { text: 'Available', color: 'bg-blue-100 text-blue-800' };
  };

  const handleLogout = () => {
    localStorage.removeItem('student');
    router.push('/');
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-xl">Loading...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16 items-center">
            <div className="flex items-center">
              <h1 className="text-xl font-bold text-gray-900">
                Examination System
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-700">
                Welcome, {student?.firstName} {student?.lastName}
              </span>
              <button
                onClick={handleLogout}
                className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Your Exams</h2>

        {exams.length === 0 ? (
          <div className="bg-white rounded-lg shadow p-6 text-center text-gray-500">
            No exams assigned yet
          </div>
        ) : (
          <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
            {exams.map((exam) => {
              const status = getExamStatus(exam);
              return (
                <div
                  key={exam.Exam_Id}
                  className="bg-white rounded-lg shadow hover:shadow-md transition-shadow p-6"
                >
                  <div className="flex justify-between items-start mb-4">
                    <h3 className="text-lg font-semibold text-gray-900">
                      {exam.Course_Name}
                    </h3>
                    <span className={`px-2 py-1 text-xs font-medium rounded ${status.color}`}>
                      {status.text}
                    </span>
                  </div>

                  <div className="space-y-2 text-sm text-gray-600">
                    <div>
                      <span className="font-medium">Start:</span>{' '}
                      {format(new Date(exam.Exam_Start_Time), 'PPp')}
                    </div>
                    <div>
                      <span className="font-medium">End:</span>{' '}
                      {format(new Date(exam.Exam_End_Time), 'PPp')}
                    </div>
                    <div>
                      <span className="font-medium">Total Grade:</span>{' '}
                      {exam.Exam_Total_Grade}
                    </div>
                    {(exam.IsCompleted || (new Date()>new Date(exam.Exam_End_Time))) && (
                      <div className="mt-3 pt-3 border-t">
                        <span className="font-medium text-green-600">
                          Your Grade: {exam.Student_Exam_Achieved_Grade}
                        </span>
                      </div>
                    )}
                  </div>

                  {canStartExam(exam) && (
                    <button
                      onClick={() => router.push(`/exam/${exam.Exam_Id}`)}
                      className="mt-4 w-full px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 font-medium"
                    >
                      Start Exam
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </main>
    </div>
  );
}