'use client';

import { useEffect, useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { Question, StudentAnswer } from '@/types';
import Countdown from 'react-countdown';

export default function ExamPage() {
  const [questions, setQuestions] = useState<Question[]>([]);
  const [answers, setAnswers] = useState<{ [key: number]: string }>({});
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [examEndTime, setExamEndTime] = useState<Date | null>(null);
  const [showResult, setShowResult] = useState(false);
  const [grade, setGrade] = useState<number>(0);
  const router = useRouter();
  const params = useParams();
  const examId = params.id as string;

  useEffect(() => {
    fetchQuestions();
  }, [examId]);

  const fetchQuestions = async () => {
    try {
      const response = await fetch(`/api/exams/${examId}/questions`);
      
      if (!response.ok) {
        const data = await response.json();
        alert(data.error || 'Failed to load exam');
        router.push('/dashboard');
        return;
      }

      const data = await response.json();
      setQuestions(data.questions);
      setExamEndTime(new Date(data.examEndTime));
    } catch (error) {
      console.error('Error fetching questions:', error);
      alert('Failed to load exam');
      router.push('/dashboard');
    } finally {
      setLoading(false);
    }
  };

  const handleAnswerChange = (questionId: number, answer: string) => {
    setAnswers({ ...answers, [questionId]: answer });
  };

  const handleSubmit = async () => {
    if (submitting) return;

    const unanswered = questions.filter(q => !answers[q.Question_Id]);
    if (unanswered.length > 0) {
      const confirm = window.confirm(
        `You have ${unanswered.length} unanswered question(s). Submit anyway?`
      );
      if (!confirm) return;
    }

    setSubmitting(true);

    try {
      const studentAnswers: StudentAnswer[] = questions.map(q => ({
        Question_Id: q.Question_Id,
        Student_Answer: answers[q.Question_Id] || '',
      }));

      const response = await fetch(`/api/exams/${examId}/submit`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ answers: studentAnswers }),
      });

      const data = await response.json();

      if (!response.ok) {
        alert(data.error || 'Failed to submit exam');
        setSubmitting(false);
        return;
      }

      setGrade(data.grade);
      setShowResult(true);
    } catch (error) {
      console.error('Error submitting exam:', error);
      alert('Failed to submit exam');
      setSubmitting(false);
    }
  };

  const handleTimeUp = () => {
    alert('Time is up! Submitting your exam...');
    handleSubmit();
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-xl">Loading exam...</div>
      </div>
    );
  }

  if (showResult) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-8 text-center">
          <div className="mb-6">
            <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg
                className="w-10 h-10 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              Exam Submitted Successfully!
            </h2>
            <p className="text-gray-600">
              Your exam has been submitted and graded.
            </p>
          </div>

          <div className="bg-indigo-50 rounded-lg p-6 mb-6">
            <p className="text-sm text-gray-600 mb-2">Your Score</p>
            <p className="text-4xl font-bold text-indigo-600">{grade}</p>
          </div>

          <button
            onClick={() => router.push('/dashboard')}
            className="w-full px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 font-medium"
          >
            Back to Dashboard
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      <div className="bg-white shadow sticky top-0 z-10">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <h1 className="text-xl font-bold text-gray-900">Exam</h1>
            {examEndTime && (
              <div className="text-lg font-semibold text-red-600">
                <Countdown
                  date={examEndTime}
                  onComplete={handleTimeUp}
                  renderer={({ hours, minutes, seconds }) => (
                    <span>
                      Time Remaining: {String(hours).padStart(2, '0')}:
                      {String(minutes).padStart(2, '0')}:
                      {String(seconds).padStart(2, '0')}
                    </span>
                  )}
                />
              </div>
            )}
          </div>
        </div>
      </div>

      <main className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="space-y-8">
          {questions.map((question, index) => (
            <div key={question.Question_Id} className="bg-white rounded-lg shadow p-6">
              <div className="mb-4">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="text-lg font-semibold text-gray-900">
                    Question {index + 1}
                  </h3>
                  <span className="text-sm text-gray-600">
                    ({question.Question_Weight} points)
                  </span>
                </div>
                <p className="text-gray-700">{question.Question_Body}</p>
              </div>

              <div className="space-y-3">
                {question.Question_Type === 'MCQ' ? (
                  question.Choices?.map((choice) => (
                    <label
                      key={choice.Choice_Label}
                      className="flex items-start p-3 border rounded-lg cursor-pointer hover:bg-gray-50"
                    >
                      <input
                        type="radio"
                        name={`question-${question.Question_Id}`}
                        value={choice.Choice_Label}
                        checked={answers[question.Question_Id] === choice.Choice_Label}
                        onChange={(e) =>
                          handleAnswerChange(question.Question_Id, e.target.value)
                        }
                        className="mt-1 mr-3"
                      />
                      <span className="text-gray-700">
                        {choice.Choice_Label}. {choice.Choice_Body}
                      </span>
                    </label>
                  ))
                ) : (
                  <div className="space-y-2">
                    <label className="flex items-center p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                      <input
                        type="radio"
                        name={`question-${question.Question_Id}`}
                        value="T"
                        checked={answers[question.Question_Id] === 'T'}
                        onChange={(e) =>
                          handleAnswerChange(question.Question_Id, e.target.value)
                        }
                        className="mr-3"
                      />
                      <span className="text-gray-700">True</span>
                    </label>
                    <label className="flex items-center p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                      <input
                        type="radio"
                        name={`question-${question.Question_Id}`}
                        value="F"
                        checked={answers[question.Question_Id] === 'F'}
                        onChange={(e) =>
                          handleAnswerChange(question.Question_Id, e.target.value)
                        }
                        className="mr-3"
                      />
                      <span className="text-gray-700">False</span>
                    </label>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="fixed bottom-0 left-0 right-0 bg-white shadow-lg border-t">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
            <button
              onClick={handleSubmit}
              disabled={submitting}
              className="w-full px-6 py-3 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {submitting ? 'Submitting...' : 'Submit Exam'}
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}