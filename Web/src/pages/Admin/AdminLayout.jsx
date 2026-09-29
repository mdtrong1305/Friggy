import React, { useState } from 'react';
import { Outlet, useNavigate, useLocation } from 'react-router-dom';
import AdminSidebar from './Sidebar/AdminSidebar';
import AdminHeader from './Header/AdminHeader';
import {
  initialStats,
  initialUsers,
  initialPackages,
  initialTransactions,
} from '../../data/adminMockData';
import { logoutHelper } from '../../services/authService';

export const AdminLayout = () => {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [stats, setStats] = useState(initialStats);
  const [users, setUsers] = useState(initialUsers);
  const [packages, setPackages] = useState(initialPackages);
  const [transactions, setTransactions] = useState(initialTransactions);
  const [openAddPackageModal, setOpenAddPackageModal] = useState(false);

  const navigate = useNavigate();
  const location = useLocation();

  const handleLogout = async () => {
    await logoutHelper();
    navigate('/', { replace: true });
  };

  const getActiveTab = () => {
    if (location.pathname.includes('/admin/ingredients')) return 'ingredients';
    if (location.pathname.includes('/admin/recipes')) return 'recipes';
    if (location.pathname.includes('/admin/users')) return 'users';
    if (location.pathname.includes('/admin/transactions')) return 'transactions';
    if (location.pathname.includes('/admin/ai')) return 'ai';
    if (location.pathname.includes('/admin/cron')) return 'cron';
    if (location.pathname.includes('/admin/sponsors')) return 'sponsors';
    if (location.pathname.includes('/admin/packages')) return 'packages';
    if (location.pathname.includes('/admin/profile')) return 'profile';
    if (location.pathname.includes('/admin/settings')) return 'settings';
    return 'dashboard';
  };

  const activeTab = getActiveTab();

  return (
    <div className="min-h-screen bg-[#f4faf6] font-sans text-slate-800 flex selection:bg-emerald-200 selection:text-emerald-900">
      {/* Sidebar Navigation */}
      <AdminSidebar
        activeTab={activeTab}
        mobileOpen={mobileOpen}
        setMobileOpen={setMobileOpen}
        onExitAdmin={handleLogout}
      />

      {/* Main Right Content Layout */}
      <div className="flex-1 flex flex-col min-w-0 lg:pl-72 transition-all duration-300">
        {/* Top Header */}
        <AdminHeader
          activeTab={activeTab}
          setMobileOpen={setMobileOpen}
          onExitAdmin={handleLogout}
        />

        {/* Tab Content Container with Pure Animate.css */}
        <main className="flex-1 p-4 sm:p-6 lg:p-8 max-w-7xl w-full mx-auto">
          <div key={location.pathname} className="animate__animated animate__fadeIn animate__faster">
            <Outlet
              context={{
                stats,
                setStats,
                users,
                setUsers,
                packages,
                setPackages,
                transactions,
                setTransactions,
                openAddPackageModal,
                setOpenAddPackageModal,
              }}
            />
          </div>
        </main>
      </div>
    </div>
  );
};

export default AdminLayout;

