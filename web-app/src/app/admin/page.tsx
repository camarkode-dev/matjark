'use client';

import { useAuth } from '@/hooks/useAuth';
import { useEffect, useState } from 'react';
import { collection, getDocs, query, where } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { User, Vendor, Product, Order } from '@/types';

export default function AdminDashboard() {
  const { user } = useAuth();
  const [stats, setStats] = useState({
    users: 0,
    vendors: 0,
    products: 0,
    orders: 0,
  });
  const [pendingVendors, setPendingVendors] = useState<Vendor[]>([]);

  useEffect(() => {
    if (user) {
      fetchStats();
      fetchPendingVendors();
    }
  }, [user]);

  const fetchStats = async () => {
    const usersSnap = await getDocs(collection(db, 'users'));
    const vendorsSnap = await getDocs(collection(db, 'vendors'));
    const productsSnap = await getDocs(collection(db, 'products'));
    const ordersSnap = await getDocs(collection(db, 'orders'));

    setStats({
      users: usersSnap.size,
      vendors: vendorsSnap.size,
      products: productsSnap.size,
      orders: ordersSnap.size,
    });
  };

  const fetchPendingVendors = async () => {
    const q = query(collection(db, 'vendors'), where('approved', '==', false));
    const querySnap = await getDocs(q);
    const vendors = querySnap.docs.map(doc => doc.data() as Vendor);
    setPendingVendors(vendors);
  };

  if (!user) {
    return <div>Please login as admin</div>;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-6">
            <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard</h1>
          </div>
        </div>
      </header>
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-medium text-gray-900">Users</h3>
              <p className="text-3xl font-bold text-indigo-600">{stats.users}</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-medium text-gray-900">Vendors</h3>
              <p className="text-3xl font-bold text-indigo-600">{stats.vendors}</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-medium text-gray-900">Products</h3>
              <p className="text-3xl font-bold text-indigo-600">{stats.products}</p>
            </div>
            <div className="bg-white p-6 rounded-lg shadow">
              <h3 className="text-lg font-medium text-gray-900">Orders</h3>
              <p className="text-3xl font-bold text-indigo-600">{stats.orders}</p>
            </div>
          </div>

          <div className="bg-white p-6 rounded-lg shadow">
            <h3 className="text-lg font-medium text-gray-900 mb-4">Pending Vendors</h3>
            <div className="space-y-4">
              {pendingVendors.map((vendor) => (
                <div key={vendor.uid} className="flex justify-between items-center p-4 border rounded">
                  <div>
                    <p className="font-medium">{vendor.storeName}</p>
                    <p className="text-sm text-gray-500">ID: {vendor.uid}</p>
                  </div>
                  <div className="space-x-2">
                    <button className="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700">
                      Approve
                    </button>
                    <button className="bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700">
                      Reject
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}