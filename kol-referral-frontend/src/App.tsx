import { Routes, Route } from 'react-router-dom';
import { Layout } from '@/components/Layout';
import { Dashboard } from '@/components/Dashboard';
import { Faucet } from '@/components/Faucet';
import { Leaderboard } from '@/components/Leaderboard';
import { Pools } from '@/components/Pools';
import { Referrals } from '@/components/Referrals';
import { Settings } from '@/components/Settings';

function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/faucet" element={<Faucet />} />
        <Route path="/leaderboard" element={<Leaderboard />} />
        <Route path="/pools" element={<Pools />} />
        <Route path="/referrals" element={<Referrals />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Layout>
  );
}

export default App; 