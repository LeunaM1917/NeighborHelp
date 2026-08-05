import { BrowserRouter, Routes, Route } from 'react-router';
import Layout from './components/Layout';
import HomePage from './pages/Home';
import BrowseServicesPage from './pages/BrowseServices';
import HowItWorksPage from './pages/HowItWorks';
import ForProvidersPage from './pages/ForProviders';
import AboutUsPage from './pages/AboutUs';
import SignUpPage from './pages/SignUp';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/signup" element={<SignUpPage />} />
        <Route path="/*" element={
          <Layout>
            <Routes>
              <Route path="/" element={<HomePage />} />
              <Route path="/browse-services" element={<BrowseServicesPage />} />
              <Route path="/how-it-works" element={<HowItWorksPage />} />
              <Route path="/for-providers" element={<ForProvidersPage />} />
              <Route path="/about-us" element={<AboutUsPage />} />
            </Routes>
          </Layout>
        } />
      </Routes>
    </BrowserRouter>
  );
}
