export interface User {
  uid: string;
  name: string;
  email: string;
  role: 'user' | 'vendor' | 'admin';
  status: 'active' | 'pending' | 'banned';
  createdAt: Date;
}

export interface Vendor {
  uid: string;
  storeName: string;
  approved: boolean;
  createdAt: Date;
}

export interface Product {
  productId: string;
  name: string;
  description: string;
  price: number;
  vendorId: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: Date;
}

export interface Order {
  orderId: string;
  userId: string;
  items: OrderItem[];
  total: number;
  status: 'processing' | 'shipped' | 'delivered' | 'returned';
  createdAt: Date;
}

export interface OrderItem {
  productId: string;
  quantity: number;
  price: number;
}

export interface Return {
  returnId: string;
  orderId: string;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
}