'use client';

import { useAuth } from '@/hooks/useAuth';
import { auth } from '@/lib/firebase';
import Link from 'next/link';

export default function Home() {
  const { user, loading } = useAuth();

  if (loading) {
    return <div className="min-h-screen flex items-center justify-center">Loading...</div>;
  }

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Welcome to Matjark</h1>
          <p className="text-lg text-gray-600 mb-8">Multi-Vendor Marketplace</p>
          <div className="space-x-4">
            <Link href="/auth/login" className="bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700">
              Login
            </Link>
            <Link href="/auth/register" className="bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700">
              Register
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <h1 className="text-2xl font-bold text-gray-900">Matjark</h1>
            <div className="flex items-center space-x-4">
              <span>Welcome, {user.email}</span>
              <button
                onClick={() => auth.signOut()}
                className="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700"
              >
                Logout
              </button>
            </div>
          </div>
        </div>
      </header>
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <h2 className="text-3xl font-bold text-gray-900 mb-4">Dashboard</h2>
          {/* Dashboard content based on role will be added here */}
          <p>Dashboard content coming soon...</p>
        </div>
      </main>
    </div>
  );
}
